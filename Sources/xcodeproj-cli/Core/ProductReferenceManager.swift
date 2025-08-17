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
    // Current implementation limited by XcodeProj library's internal productReference property
    throw ProjectError.libraryLimitation(
      "Product reference repair requires XcodeProj library v10.0+. Current functionality creates Products group and references but cannot link to targets. Use 'validate-products' to check project structure."
    )
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

    // Note library limitation for full validation
    if !pbxproj.nativeTargets.isEmpty {
      issues.append(
        ValidationIssue(
          type: .missingProductReference,
          message: "Complete product reference validation requires XcodeProj library v10.0+",
          severity: .info
        )
      )
    }

    return issues
  }

  func findOrphanedProducts() -> [PBXFileReference] {
    guard let productsGroup = pbxproj.rootObject?.productsGroup else { return [] }

    // Since we can't access productReference, return all products as potentially orphaned
    // Use lazy evaluation for memory efficiency with large projects
    return productsGroup.children.lazy
      .compactMap { $0 as? PBXFileReference }
      // NOTE: The filter { _ in true } is intentionally a no-op placeholder.
      // When XcodeProj library v10.0+ provides access to productReference,
      // this will be replaced with actual orphan detection logic:
      // .filter { !isReferencedByAnyTarget($0) }
      .filter { _ in true }
  }

  func removeOrphanedProducts() throws -> Int {
    throw ProjectError.libraryLimitation(
      "Orphaned product removal requires XcodeProj library v10.0+ for productReference access. Use manual cleanup through Xcode or wait for library update."
    )
  }

  func addProductReference(
    to target: PBXNativeTarget, productName: String? = nil, productType: PBXProductType? = nil
  ) throws {
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

    // Library limitation: Cannot set target.productReference due to internal property access
    // Reference created in Products group but target linking requires XcodeProj library v10.0+
  }

  func findMissingProductReferences() -> [PBXNativeTarget] {
    // Current limitation: Cannot access productReference property
    // Return targets that likely need product references based on available data

    // Early return if no products group
    guard let productsGroup = pbxproj.rootObject?.productsGroup else {
      return pbxproj.nativeTargets
    }

    // Build a set of existing product names for O(1) lookup
    let existingProducts = Set(
      productsGroup.children.lazy.flatMap { child -> [String] in
        var names: [String] = []
        if let name = child.name { names.append(name) }
        if let path = child.path { names.append(path) }
        return names
      }
    )

    // Filter targets using O(1) set lookup instead of O(m) array search
    return pbxproj.nativeTargets.filter { target in
      let expectedProductName = target.productNameForReference() ?? "\(target.name).app"
      return !existingProducts.contains(expectedProductName)
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

  private func getSwiftVersion() -> String {
    // Try to detect from existing project first, fall back to current Swift version
    if let projectConfig = pbxproj.rootObject?.buildConfigurationList?.buildConfigurations.first,
      let existingVersion = projectConfig.buildSettings["SWIFT_VERSION"],
      case .string(let versionString) = existingVersion
    {
      return versionString
    }
    // Default to Swift 6.0 for new configurations
    return "6.0"
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

struct ValidationIssue: Sendable {
  enum IssueType: Sendable {
    case missingProductReference
    case orphanedProductReference
    case missingProductsGroup
    case invalidProductPath
  }

  let type: IssueType
  let message: String

  // Structured data for programmatic access
  let targetName: String?
  let productName: String?
  let severity: Severity

  enum Severity: String, Sendable {
    case error
    case warning
    case info
  }

  init(
    type: IssueType,
    message: String,
    targetName: String? = nil,
    productName: String? = nil,
    severity: Severity = .error
  ) {
    self.type = type
    self.message = message
    self.targetName = targetName
    self.productName = productName
    self.severity = severity
  }
}
