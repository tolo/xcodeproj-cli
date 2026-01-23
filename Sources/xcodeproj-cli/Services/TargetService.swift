//
// TargetService.swift
// xcodeproj-cli
//

import Foundation
@preconcurrency import XcodeProj

/// Service for target management in Xcode projects
@MainActor
final class TargetService {
  private let pbxproj: PBXProj
  private let cacheManager: CacheManager
  private let buildPhaseManager: BuildPhaseManager
  private let profiler: PerformanceProfiler?

  init(
    pbxproj: PBXProj,
    cacheManager: CacheManager,
    buildPhaseManager: BuildPhaseManager,
    profiler: PerformanceProfiler? = nil
  ) {
    self.pbxproj = pbxproj
    self.cacheManager = cacheManager
    self.buildPhaseManager = buildPhaseManager
    self.profiler = profiler
  }

  // MARK: - Target Management

  func addTarget(name: String, productType: String, bundleId: String, platform: String = "iOS")
    throws
  {
    // Check if target already exists using cache
    if cacheManager.getTarget(name) != nil {
      throw ProjectError.operationFailed("Target \(name) already exists")
    }

    // Create build configurations
    let swiftVersion = getSwiftVersion()
    let debugConfig = XCBuildConfiguration(name: "Debug")
    debugConfig.buildSettings = [
      "BUNDLE_IDENTIFIER": .string(bundleId),
      "PRODUCT_NAME": .string("$(TARGET_NAME)"),
      "SWIFT_VERSION": .string(swiftVersion),
    ]

    let releaseConfig = XCBuildConfiguration(name: "Release")
    releaseConfig.buildSettings = [
      "BUNDLE_IDENTIFIER": .string(bundleId),
      "PRODUCT_NAME": .string("$(TARGET_NAME)"),
      "SWIFT_VERSION": .string(swiftVersion),
    ]

    pbxproj.add(object: debugConfig)
    pbxproj.add(object: releaseConfig)

    let configList = XCConfigurationList(buildConfigurations: [debugConfig, releaseConfig])
    pbxproj.add(object: configList)

    // Create target
    let target = PBXNativeTarget(
      name: name,
      buildConfigurationList: configList,
      buildPhases: [],
      buildRules: [],
      dependencies: [],
      productInstallPath: nil,
      productName: name,
      productType: PBXProductType(rawValue: productType)
    )

    // Add build phases
    let sourcesBuildPhase = PBXSourcesBuildPhase()
    let resourcesBuildPhase = PBXResourcesBuildPhase()
    let frameworksBuildPhase = PBXFrameworksBuildPhase()

    pbxproj.add(object: sourcesBuildPhase)
    pbxproj.add(object: resourcesBuildPhase)
    pbxproj.add(object: frameworksBuildPhase)

    target.buildPhases = [sourcesBuildPhase, frameworksBuildPhase, resourcesBuildPhase]

    pbxproj.add(object: target)
    pbxproj.rootObject?.targets.append(target)

    // Create and link product reference
    let productManager = ProductReferenceManager(pbxproj: pbxproj)
    if let productTypeEnum = PBXProductType(rawValue: productType) {
      let productRef = try productManager.createProductReference(
        for: target, productType: productTypeEnum)
      target.product = productRef
    }

    // Invalidate cache to pick up new target
    cacheManager.invalidateTarget(name)
    cacheManager.rebuildAllCaches()

    print("✅ Added target: \(name) (\(productType))")
  }

  func duplicateTarget(source: String, newName: String, newBundleId: String? = nil) throws {
    guard let sourceTarget = cacheManager.getTarget(source) else {
      throw ProjectError.targetNotFound(source)
    }

    // Check if new target already exists using cache
    if cacheManager.getTarget(newName) != nil {
      throw ProjectError.operationFailed("Target \(newName) already exists")
    }

    // Clone build configuration list
    guard let sourceConfigList = sourceTarget.buildConfigurationList else {
      throw ProjectError.operationFailed("Source target has no build configurations")
    }

    var newConfigs: [XCBuildConfiguration] = []
    for sourceConfig in sourceConfigList.buildConfigurations {
      let newConfig = XCBuildConfiguration(name: sourceConfig.name)
      newConfig.buildSettings = sourceConfig.buildSettings

      // Update bundle identifier if provided
      if let bundleId = newBundleId {
        newConfig.buildSettings["BUNDLE_IDENTIFIER"] = .string(bundleId)
      }

      pbxproj.add(object: newConfig)
      newConfigs.append(newConfig)
    }

    let newConfigList = XCConfigurationList(buildConfigurations: newConfigs)
    pbxproj.add(object: newConfigList)

    // Create new target
    let newTarget = PBXNativeTarget(
      name: newName,
      buildConfigurationList: newConfigList,
      buildPhases: [],
      buildRules: sourceTarget.buildRules,
      dependencies: [],
      productInstallPath: sourceTarget.productInstallPath,
      productName: newName,
      productType: sourceTarget.productType
    )

    // Clone build phases with deep copy of build files
    for phase in sourceTarget.buildPhases {
      if let sourcePhase = phase as? PBXSourcesBuildPhase {
        let newPhase = PBXSourcesBuildPhase()
        newPhase.files = cloneBuildFiles(from: sourcePhase.files)
        pbxproj.add(object: newPhase)
        newTarget.buildPhases.append(newPhase)
      } else if let resourcePhase = phase as? PBXResourcesBuildPhase {
        let newPhase = PBXResourcesBuildPhase()
        newPhase.files = cloneBuildFiles(from: resourcePhase.files)
        pbxproj.add(object: newPhase)
        newTarget.buildPhases.append(newPhase)
      } else if let frameworkPhase = phase as? PBXFrameworksBuildPhase {
        let newPhase = PBXFrameworksBuildPhase()
        newPhase.files = cloneBuildFiles(from: frameworkPhase.files)
        pbxproj.add(object: newPhase)
        newTarget.buildPhases.append(newPhase)
      }
    }

    pbxproj.add(object: newTarget)
    pbxproj.rootObject?.targets.append(newTarget)

    // Create and link product reference for the duplicated target
    if let productType = newTarget.productType {
      let productManager = ProductReferenceManager(pbxproj: pbxproj)
      let productRef = try productManager.createProductReference(
        for: newTarget, productType: productType)
      newTarget.product = productRef
    }

    // Invalidate cache to pick up new target
    cacheManager.invalidateTarget(newName)
    cacheManager.rebuildAllCaches()

    print("✅ Duplicated target: \(source) -> \(newName)")
  }

  func removeTarget(name: String) throws {
    guard let target = cacheManager.getTarget(name) else {
      throw ProjectError.targetNotFound(name)
    }

    // Remove product reference from Products group if it exists
    if let product = target.product,
      let productsGroup = pbxproj.rootObject?.productsGroup,
      let index = productsGroup.children.firstIndex(of: product)
    {
      productsGroup.children.remove(at: index)
      pbxproj.delete(object: product)
    }

    // Remove from project targets
    pbxproj.rootObject?.targets.removeAll { $0 === target }

    // Remove dependencies from other targets
    for otherTarget in pbxproj.nativeTargets {
      otherTarget.dependencies.removeAll { dependency in
        dependency.target === target
      }
    }

    // Remove from project
    pbxproj.delete(object: target)

    // Invalidate cache
    cacheManager.invalidateTarget(name)

    print("✅ Removed target: \(name)")
  }

  // MARK: - Dependencies

  func addDependency(to targetName: String, dependsOn dependencyName: String) throws {
    guard let target = cacheManager.getTarget(targetName) else {
      throw ProjectError.targetNotFound(targetName)
    }

    guard let dependency = cacheManager.getTarget(dependencyName) else {
      throw ProjectError.targetNotFound(dependencyName)
    }

    // Check if dependency already exists
    if target.dependencies.contains(where: { $0.target === dependency }) {
      print("⚠️  Dependency already exists")
      return
    }

    let targetDependency = PBXTargetDependency(target: dependency)
    pbxproj.add(object: targetDependency)
    target.dependencies.append(targetDependency)

    print("✅ Added dependency: \(targetName) -> \(dependencyName)")
  }

  // MARK: - Helper Methods

  /// Deep clone build files to prevent corruption when duplicating targets
  private func cloneBuildFiles(from sourceFiles: [PBXBuildFile]?) -> [PBXBuildFile] {
    guard let sourceFiles = sourceFiles else {
      return []
    }

    var newFiles: [PBXBuildFile] = []
    for sourceBuildFile in sourceFiles {
      if let fileRef = sourceBuildFile.file {
        let newBuildFile = PBXBuildFile(file: fileRef)
        newBuildFile.settings = sourceBuildFile.settings
        pbxproj.add(object: newBuildFile)
        newFiles.append(newBuildFile)
      }
    }
    return newFiles
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
}
