//
// CrossProjectManager.swift
// xcodeproj-cli
//
// Service for managing cross-project references and dependencies
//

import Foundation
@preconcurrency import PathKit
@preconcurrency import XcodeProj

/// Service for managing cross-project references and dependencies
@MainActor
class CrossProjectManager {
  private let xcodeproj: XcodeProj
  private let projectPath: Path
  private let pbxproj: PBXProj
  private let transactionManager: TransactionManager

  init(xcodeproj: XcodeProj, projectPath: Path) {
    self.xcodeproj = xcodeproj
    self.projectPath = projectPath
    self.pbxproj = xcodeproj.pbxproj
    self.transactionManager = TransactionManager(projectPath: projectPath)
  }

  // MARK: - Transaction Support

  /// Begins a transaction for cross-project modifications
  func beginTransaction() throws {
    try transactionManager.beginTransaction()
  }

  /// Commits the current transaction
  func commitTransaction() throws {
    try transactionManager.commitTransaction()
  }

  /// Rolls back the current transaction
  func rollbackTransaction() throws {
    try transactionManager.rollbackTransaction()
  }

  // MARK: - Project References

  /// Adds a reference to an external project
  func addProjectReference(
    externalProjectPath: String,
    groupPath: String? = nil
  ) throws -> PBXFileReference {
    // Validate external project path for security
    let resolvedPath = try PathUtils.validatePath(externalProjectPath)

    // Check if reference already exists
    if let existingRef = pbxproj.fileReferences.first(where: {
      $0.path == resolvedPath && $0.lastKnownFileType == "wrapper.pb-project"
    }) {
      print("⚠️  Project reference already exists: \(resolvedPath)")
      return existingRef
    }

    // Find or create the group
    let group: PBXGroup
    if let groupPath = groupPath {
      group = try findOrCreateGroup(path: groupPath)
    } else {
      guard let mainGroup = pbxproj.rootObject?.mainGroup ?? pbxproj.groups.first else {
        throw ProjectError.operationFailed("No main group or root groups found in project")
      }
      group = mainGroup
    }

    // Create file reference for the external project
    let projectName = Path(resolvedPath).lastComponentWithoutExtension
    let fileRef = PBXFileReference(
      sourceTree: .group,
      name: projectName,
      lastKnownFileType: "wrapper.pb-project",
      path: resolvedPath
    )

    // Add to project
    pbxproj.add(object: fileRef)
    group.children.append(fileRef)

    print("✅ Added project reference: \(projectName) at \(resolvedPath)")

    return fileRef
  }

  /// Removes a project reference
  func removeProjectReference(projectPath: String) throws {
    // Find the reference
    guard
      let fileRef = pbxproj.fileReferences.first(where: {
        ($0.path == projectPath || $0.path?.hasSuffix(projectPath) == true)
          && $0.lastKnownFileType == "wrapper.pb-project"
      })
    else {
      throw ProjectError.operationFailed("Project reference not found: \(projectPath)")
    }

    // Remove from all groups
    for group in pbxproj.groups {
      group.children.removeAll { $0 === fileRef }
    }

    // Remove associated proxies and dependencies
    let proxiesToRemove = pbxproj.containerItemProxies.filter { proxy in
      if case .fileReference(let ref) = proxy.containerPortal {
        return ref === fileRef
      }
      return false
    }

    for proxy in proxiesToRemove {
      // Remove target dependencies using this proxy
      for target in pbxproj.nativeTargets {
        target.dependencies.removeAll { dep in
          dep.targetProxy === proxy
        }
      }

      // Remove the proxy
      pbxproj.delete(object: proxy)
    }

    // Remove the file reference
    pbxproj.delete(object: fileRef)

    print("✅ Removed project reference: \(projectPath)")
  }

  // MARK: - Cross-Project Dependencies

  /// Adds a dependency on a target in an external project
  func addCrossProjectDependency(
    targetName: String,
    externalProjectPath: String,
    externalTargetName: String,
    externalTargetGUID: String? = nil
  ) throws {
    // Find the target
    guard let target = pbxproj.targets(named: targetName).first else {
      throw ProjectError.targetNotFound(targetName)
    }

    // Find or add the external project reference
    let projectRef: PBXFileReference
    if let existingRef = findProjectReference(path: externalProjectPath) {
      projectRef = existingRef
    } else {
      projectRef = try addProjectReference(externalProjectPath: externalProjectPath)
    }

    // Wire the external target GUID if provided
    let remoteGlobalIDRef: PBXContainerItemProxy.RemoteGlobalID?
    if let guid = externalTargetGUID {
      // Convert String GUID to RemoteGlobalID
      remoteGlobalIDRef = .string(guid)
    } else {
      // Keep nil for backward compatibility - use name-based lookup
      remoteGlobalIDRef = nil
    }

    // Create container item proxy for the dependency
    let containerProxy = PBXContainerItemProxy(
      containerPortal: .fileReference(projectRef),
      remoteGlobalID: remoteGlobalIDRef,
      proxyType: .nativeTarget,
      remoteInfo: externalTargetName
    )
    pbxproj.add(object: containerProxy)

    // Create reference proxy (for the build product)
    let productRef = PBXReferenceProxy(
      fileType: "archive.ar",  // Default, would need to determine from external project
      path: externalTargetName,
      remote: containerProxy,
      sourceTree: .buildProductsDir
    )
    pbxproj.add(object: productRef)

    // Create target dependency
    let targetDependency = PBXTargetDependency(
      name: externalTargetName,
      targetProxy: containerProxy
    )
    pbxproj.add(object: targetDependency)

    // Add to target's dependencies
    target.dependencies.append(targetDependency)

    print(
      "✅ Added cross-project dependency: \(targetName) -> \(externalTargetName) in \(externalProjectPath)"
    )
  }

  /// Removes a cross-project dependency
  func removeCrossProjectDependency(
    targetName: String,
    externalTargetName: String
  ) throws {
    // Find the target
    guard let target = pbxproj.targets(named: targetName).first else {
      throw ProjectError.targetNotFound(targetName)
    }

    // Find and remove the dependency
    var found = false
    target.dependencies.removeAll { dep in
      if dep.name == externalTargetName {
        // Remove associated proxy if it exists
        if let proxy = dep.targetProxy {
          pbxproj.delete(object: proxy)
        }
        // Remove the dependency object
        pbxproj.delete(object: dep)
        found = true
        return true
      }
      return false
    }

    if !found {
      throw ProjectError.operationFailed(
        "Dependency '\(externalTargetName)' not found in target '\(targetName)'")
    }

    print("✅ Removed cross-project dependency: \(targetName) -> \(externalTargetName)")
  }

  /// Lists all cross-project dependencies for a target
  func listCrossProjectDependencies(targetName: String) throws -> [(
    project: String, target: String
  )] {
    guard let target = pbxproj.targets(named: targetName).first else {
      throw ProjectError.targetNotFound(targetName)
    }

    var dependencies: [(project: String, target: String)] = []

    for dep in target.dependencies {
      if let proxy = dep.targetProxy,
        case .fileReference(let fileRef) = proxy.containerPortal
      {
        let projectName = fileRef.name ?? fileRef.path ?? "Unknown"
        let targetName = dep.name ?? proxy.remoteInfo ?? "Unknown"
        dependencies.append((project: projectName, target: targetName))
      }
    }

    return dependencies
  }

  // MARK: - Private Helpers

  private func findProjectReference(path: String) -> PBXFileReference? {
    return pbxproj.fileReferences.first { ref in
      ref.lastKnownFileType == "wrapper.pb-project"
        && (ref.path == path || ref.path?.hasSuffix(path) == true || path.hasSuffix(ref.path ?? ""))
    }
  }

  private func findOrCreateGroup(path: String) throws -> PBXGroup {
    let components = path.split(separator: "/").map(String.init)

    guard !components.isEmpty else {
      guard let mainGroup = pbxproj.rootObject?.mainGroup else {
        throw ProjectError.operationFailed("No main group found in project")
      }
      return mainGroup
    }

    guard let startingGroup = pbxproj.rootObject?.mainGroup ?? pbxproj.groups.first else {
      throw ProjectError.operationFailed("No main group or groups found in project")
    }
    var currentGroup = startingGroup

    for component in components {
      if let existingGroup = currentGroup.children.compactMap({ $0 as? PBXGroup }).first(where: {
        $0.name == component || $0.path == component
      }) {
        currentGroup = existingGroup
      } else {
        // Create new group
        let newGroup = PBXGroup(sourceTree: .group, name: component)
        pbxproj.add(object: newGroup)
        currentGroup.children.append(newGroup)
        currentGroup = newGroup
      }
    }

    return currentGroup
  }
}
