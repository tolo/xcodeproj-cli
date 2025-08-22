import Foundation
import PathKit
import XcodeProj

@MainActor
class ProductReferenceManager {
  private let pbxproj: PBXProj

  init(pbxproj: PBXProj) {
    self.pbxproj = pbxproj
  }

  func createProductReference(for target: PBXNativeTarget, productType: PBXProductType) throws
    -> PBXFileReference
  {
    let productName =
      target.productNameForReference() ?? "\(target.name).\(productType.fileExtension ?? "app")"
    
    // Validate the generated product name for security
    try ProductCommandBase.validateProductNameSecurity(productName)

    let productRef = PBXFileReference(
      sourceTree: .buildProductsDir,
      name: productName,
      explicitFileType: productType.explicitFileType,
      path: productName,
      includeInIndex: false
    )

    pbxproj.add(object: productRef)

    let productsGroup = try ensureProductsGroup()
    if !productsGroup.children.contains(productRef) {
      productsGroup.children.append(productRef)
    }

    return productRef
  }

  func ensureProductsGroup() throws -> PBXGroup {
    if let existingGroup = pbxproj.rootObject?.productsGroup {
      return existingGroup
    }

    let productsGroup = PBXGroup(
      sourceTree: .buildProductsDir,
      name: "Products"
    )
    pbxproj.add(object: productsGroup)

    pbxproj.rootObject?.productsGroup = productsGroup

    if let mainGroup = pbxproj.rootObject?.mainGroup {
      mainGroup.children.append(productsGroup)
    }

    return productsGroup
  }

  func repairProductReferences(dryRun: Bool = false, targetNames: [String]? = nil) throws
    -> [String]
  {
    var repaired: [String] = []

    // Ensure Products group exists
    let _ = try ensureProductsGroup()

    // Find targets missing product references
    let targetsToRepair = pbxproj.nativeTargets.filter { target in
      if let targetNames = targetNames, !targetNames.contains(target.name) {
        return false
      }
      return target.product == nil && target.productType != nil
    }

    for target in targetsToRepair {
      if !dryRun {
        // Safely get product type - this should always succeed since we filtered above
        guard let productType = target.productType else {
          throw ProjectError.invalidConfiguration("Target '\(target.name)' has no product type")
        }
        
        // Create and link product reference
        let productRef = try createProductReference(for: target, productType: productType)
        target.product = productRef
      }
      repaired.append("Repaired product reference for target '\(target.name)'")
    }

    return repaired
  }

  func validateProducts() throws -> [ValidationIssue] {
    var issues: [ValidationIssue] = []

    let productsGroup = pbxproj.rootObject?.productsGroup
    if productsGroup == nil {
      issues.append(
        ValidationIssue(
          type: .missingProductsGroup,
          message: "Products group is missing from project",
          severity: .error
        ))
    }

    // Validate what we can with current library capabilities
    for target in pbxproj.nativeTargets {
      // Check if target has proper product type
      if target.productType == nil {
        issues.append(
          ValidationIssue(
            type: .missingProductReference,
            message: "Target '\(target.name)' missing product type specification",
            targetName: target.name,
            severity: .error
          )
        )
      }
    }

    // Check for missing product references
    for target in pbxproj.nativeTargets {
      if target.product == nil && target.productType != nil {
        issues.append(
          ValidationIssue(
            type: .missingProductReference,
            message: "Target '\(target.name)' missing product reference",
            targetName: target.name,
            severity: .error
          )
        )
      }
    }

    return issues
  }

  func findOrphanedProducts() -> [PBXFileReference] {
    guard let productsGroup = pbxproj.rootObject?.productsGroup else { return [] }

    // Build set of all products referenced by targets for O(1) lookup
    let referencedProducts = Set(pbxproj.nativeTargets.compactMap { $0.product })

    // Find products in Products group that aren't referenced by any target
    return productsGroup.children
      .compactMap { $0 as? PBXFileReference }
      .filter { !referencedProducts.contains($0) }
  }

  func removeOrphanedProducts() throws -> Int {
    guard let productsGroup = pbxproj.rootObject?.productsGroup else { return 0 }

    let orphanedProducts = findOrphanedProducts()
    let count = orphanedProducts.count

    for product in orphanedProducts {
      // Remove from Products group
      if let index = productsGroup.children.firstIndex(of: product) {
        productsGroup.children.remove(at: index)
      }
      
      // Remove from pbxproj objects
      pbxproj.delete(object: product)
    }

    return count
  }

  func addProductReference(
    to target: PBXNativeTarget, productName: String? = nil, productType: PBXProductType? = nil
  ) throws {
    // Check if target already has a product reference to prevent duplicates
    if target.product != nil {
      print("ℹ️  Target already has a product reference")
      return
    }
    
    // Validate product name if provided using the shared validation
    if let name = productName {
      try ProductCommandBase.validateProductNameSecurity(name)
    }

    let actualProductType = productType ?? target.productType ?? .application

    let productRef = try createProductReference(for: target, productType: actualProductType)

    if let customName = productName {
      productRef.name = customName
      productRef.path = customName
    }

    // Link the product reference to the target
    target.product = productRef
  }

  func findMissingProductReferences() -> [PBXNativeTarget] {
    // Return targets that don't have a product reference but should have one
    return pbxproj.nativeTargets.filter { target in
      target.product == nil && target.productType != nil
    }
  }

  func repairTargets(targetName: String? = nil) throws -> [String] {
    var repaired: [String] = []
    let targets = pbxproj.nativeTargets

    for target in targets {
      if let targetName = targetName, target.name != targetName {
        continue
      }

      var targetRepaired = false

      // Add missing build phases if needed
      if target.buildPhases.isEmpty {
        try addMissingBuildPhases(to: target)
        repaired.append("Added missing build phases to target '\(target.name)'")
        targetRepaired = true
      }

      // Add missing build configurations if needed
      if target.buildConfigurationList == nil {
        try addMissingBuildConfigurations(to: target)
        repaired.append("Added missing build configurations to target '\(target.name)'")
        targetRepaired = true
      }

      if targetRepaired {
        repaired.append("Repaired target '\(target.name)'")
      }
    }

    return repaired
  }

  // MARK: - Target Repair Helper Methods

  private func addMissingBuildPhases(to target: PBXNativeTarget) throws {
    let sourcesBuildPhase = PBXSourcesBuildPhase()
    pbxproj.add(object: sourcesBuildPhase)
    target.buildPhases.append(sourcesBuildPhase)

    let resourcesBuildPhase = PBXResourcesBuildPhase()
    pbxproj.add(object: resourcesBuildPhase)
    target.buildPhases.append(resourcesBuildPhase)

    let frameworksBuildPhase = PBXFrameworksBuildPhase()
    pbxproj.add(object: frameworksBuildPhase)
    target.buildPhases.append(frameworksBuildPhase)
  }

  private func getSwiftVersion() -> String {
    // Try to detect from existing project first
    if let projectConfig = pbxproj.rootObject?.buildConfigurationList?.buildConfigurations.first,
      let existingVersion = projectConfig.buildSettings["SWIFT_VERSION"],
      case .string(let versionString) = existingVersion
    {
      return versionString
    }
    
    // Check environment variable override
    if let envSwiftVersion = ProcessInfo.processInfo.environment["XCODEPROJ_CLI_SWIFT_VERSION"] {
      return envSwiftVersion
    }
    
    // Try to detect current Swift version from runtime
    if #available(macOS 10.15, *) {
      // Use Swift version constants available at runtime
      #if swift(>=6.0)
        return "6.0"
      #elseif swift(>=5.9)
        return "5.9"
      #elseif swift(>=5.8)
        return "5.8"
      #else
        return "5.7"
      #endif
    }
    
    // Final fallback
    return "6.0"
  }

  private func addMissingBuildConfigurations(to target: PBXNativeTarget) throws {
    let swiftVersion = getSwiftVersion()

    let debugConfig = XCBuildConfiguration(
      name: "Debug",
      buildSettings: [
        "PRODUCT_NAME": .string("$(TARGET_NAME)"),
        "SWIFT_VERSION": .string(swiftVersion),
      ]
    )
    pbxproj.add(object: debugConfig)

    let releaseConfig = XCBuildConfiguration(
      name: "Release",
      buildSettings: [
        "PRODUCT_NAME": .string("$(TARGET_NAME)"),
        "SWIFT_VERSION": .string(swiftVersion),
      ]
    )
    pbxproj.add(object: releaseConfig)

    let configList = XCConfigurationList(
      buildConfigurations: [debugConfig, releaseConfig],
      defaultConfigurationName: "Debug"
    )
    pbxproj.add(object: configList)

    target.buildConfigurationList = configList
  }

}

extension PBXProductType {
  var fileExtension: String? {
    switch self {
    case .application: return "app"
    case .framework: return "framework"
    case .staticLibrary: return "a"
    case .dynamicLibrary: return "dylib"
    case .unitTestBundle: return "xctest"
    case .uiTestBundle: return "xctest"
    case .appExtension: return "appex"
    case .commandLineTool: return nil
    case .bundle: return "bundle"
    case .watch2App: return "app"
    case .watch2Extension: return "appex"
    case .tvExtension: return "appex"
    case .messagesApplication: return "app"
    case .messagesExtension: return "appex"
    case .stickerPack: return "appex"
    case .xpcService: return "xpc"
    case .ocUnitTestBundle: return "octest"
    case .xcodeExtension: return "appex"
    case .instrumentsPackage: return "instrpkg"
    case .intentsServiceExtension: return "appex"
    case .onDemandInstallCapableApplication: return "app"
    case .metalLibrary: return "metallib"
    case .driverExtension: return "dext"
    case .systemExtension: return "systemextension"
    case .extensionKitExtension: return "appex"
    default: return nil
    }
  }

  var explicitFileType: String? {
    switch self {
    case .application: return "wrapper.application"
    case .framework: return "wrapper.framework"
    case .staticLibrary: return "archive.ar"
    case .dynamicLibrary: return "compiled.mach-o.dylib"
    case .unitTestBundle: return "wrapper.cfbundle"
    case .uiTestBundle: return "wrapper.cfbundle"
    case .appExtension: return "wrapper.app-extension"
    case .commandLineTool: return "compiled.mach-o.executable"
    case .bundle: return "wrapper.cfbundle"
    case .watch2App: return "wrapper.application"
    case .watch2Extension: return "wrapper.app-extension"
    case .tvExtension: return "wrapper.app-extension"
    case .messagesApplication: return "wrapper.application"
    case .messagesExtension: return "wrapper.app-extension"
    case .stickerPack: return "wrapper.app-extension"
    case .xpcService: return "wrapper.xpc-service"
    case .ocUnitTestBundle: return "wrapper.cfbundle"
    case .xcodeExtension: return "wrapper.app-extension"
    case .instrumentsPackage: return "com.apple.instruments.instrdst"
    case .intentsServiceExtension: return "wrapper.app-extension"
    case .onDemandInstallCapableApplication: return "wrapper.application"
    case .metalLibrary: return "archive.metal-library"
    case .driverExtension: return "wrapper.driver-extension"
    case .systemExtension: return "wrapper.system-extension"
    case .extensionKitExtension: return "wrapper.app-extension"
    default: return nil
    }
  }
}

