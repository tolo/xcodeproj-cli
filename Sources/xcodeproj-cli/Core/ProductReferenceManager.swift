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
    var repaired: [String] = []
    let targets = pbxproj.nativeTargets

    for target in targets {
      if let targetNames = targetNames, !targetNames.contains(target.name) {
        continue
      }

      // TODO: Implement when productReference is accessible
      // This requires access to the internal productReference property
      repaired.append(
        "Product reference management requires XcodeProj library update for target '\(target.name)'"
      )
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
          message: "Products group is missing from project"
        ))
    }

    // TODO: Add product reference validation when productReference is accessible
    issues.append(
      ValidationIssue(
        type: .missingProductReference,
        message: "Product reference validation requires XcodeProj library update"
      ))

    return issues
  }

  func findOrphanedProducts() -> [PBXFileReference] {
    guard let productsGroup = pbxproj.rootObject?.productsGroup else { return [] }

    // Since we can't access productReference, return all products as potentially orphaned
    // Use compactMap for more efficient filtering
    return productsGroup.children.compactMap { $0 as? PBXFileReference }
  }

  func removeOrphanedProducts() throws -> Int {
    // TODO: Implement when productReference is accessible
    return 0
  }

  func addProductReference(
    to target: PBXNativeTarget, productName: String? = nil, productType: PBXProductType? = nil
  ) throws {
    // Validate product name if provided
    if let name = productName {
      try validateProductName(name)
    }
    
    let actualProductType = productType ?? target.productType ?? .application

    let productRef = try createProductReference(for: target, productType: actualProductType)

    if let customName = productName {
      productRef.name = customName
      productRef.path = customName
    }

    // TODO: Set target.productReference when property becomes accessible
    // Note: Product reference created but cannot be linked to target due to XcodeProj library limitations
  }

  func findMissingProductReferences() -> [PBXNativeTarget] {
    // TODO: Implement when productReference is accessible
    return pbxproj.nativeTargets
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
        let sourcesBuildPhase = PBXSourcesBuildPhase()
        pbxproj.add(object: sourcesBuildPhase)
        target.buildPhases.append(sourcesBuildPhase)

        let resourcesBuildPhase = PBXResourcesBuildPhase()
        pbxproj.add(object: resourcesBuildPhase)
        target.buildPhases.append(resourcesBuildPhase)

        let frameworksBuildPhase = PBXFrameworksBuildPhase()
        pbxproj.add(object: frameworksBuildPhase)
        target.buildPhases.append(frameworksBuildPhase)

        repaired.append("Added missing build phases to target '\(target.name)'")
        targetRepaired = true
      }

      if target.buildConfigurationList == nil {
        let debugConfig = XCBuildConfiguration(
          name: "Debug",
          buildSettings: [
            "PRODUCT_NAME": "$(TARGET_NAME)",
            "SWIFT_VERSION": "6.0",
          ]
        )
        pbxproj.add(object: debugConfig)

        let releaseConfig = XCBuildConfiguration(
          name: "Release",
          buildSettings: [
            "PRODUCT_NAME": "$(TARGET_NAME)",
            "SWIFT_VERSION": "6.0",
          ]
        )
        pbxproj.add(object: releaseConfig)

        let configList = XCConfigurationList(
          buildConfigurations: [debugConfig, releaseConfig],
          defaultConfigurationName: "Debug"
        )
        pbxproj.add(object: configList)

        target.buildConfigurationList = configList
        repaired.append("Added missing build configurations to target '\(target.name)'")
        targetRepaired = true
      }

      if targetRepaired {
        repaired.append("Repaired target '\(target.name)'")
      }
    }

    return repaired
  }
  
  // MARK: - Private Helper Methods
  
  private func validateProductName(_ name: String) throws {
    // Check for empty or whitespace-only names
    guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw ProjectError.invalidArguments("Product name cannot be empty or whitespace")
    }
    
    // Check for reasonable length (max 255 characters)
    guard name.count <= 255 else {
      throw ProjectError.invalidArguments("Product name cannot exceed 255 characters")
    }
    
    // Check for path traversal attempts
    guard !name.contains("../") && !name.contains("..\\") else {
      throw ProjectError.invalidArguments("Product name cannot contain path traversal sequences")
    }
    
    // Check for invalid characters that could cause issues in file systems
    let invalidCharacters = CharacterSet(charactersIn: "<>:\"|?*")
    guard name.rangeOfCharacter(from: invalidCharacters) == nil else {
      throw ProjectError.invalidArguments("Product name contains invalid characters (<>:\"|?*)")
    }
    
    // Check for control characters
    guard name.rangeOfCharacter(from: .controlCharacters) == nil else {
      throw ProjectError.invalidArguments("Product name cannot contain control characters")
    }
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
}
