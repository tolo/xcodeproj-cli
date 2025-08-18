//
// WorkspaceManager.swift
// xcodeproj-cli
//
// Service for managing Xcode workspaces
//

import Foundation
@preconcurrency import PathKit
@preconcurrency import XcodeProj

/// Service for managing Xcode workspaces
@MainActor
class WorkspaceManager {
  private let workingDirectory: Path
  private let transactionManager: TransactionManager?

  init(
    workingDirectory: String = FileManager.default.currentDirectoryPath, projectPath: String? = nil
  ) {
    self.workingDirectory = Path(workingDirectory)
    self.transactionManager = projectPath.map { TransactionManager(projectPath: Path($0)) }
  }

  // MARK: - Transaction Support

  /// Begins a transaction for workspace modifications
  func beginTransaction() throws {
    guard let transactionManager = transactionManager else {
      return  // No transaction manager available for workspace-only operations
    }
    try transactionManager.beginTransaction()
  }

  /// Commits the current transaction
  func commitTransaction() throws {
    guard let transactionManager = transactionManager else {
      return  // No transaction manager available for workspace-only operations
    }
    try transactionManager.commitTransaction()
  }

  /// Rolls back the current transaction
  func rollbackTransaction() throws {
    guard let transactionManager = transactionManager else {
      return  // No transaction manager available for workspace-only operations
    }
    try transactionManager.rollbackTransaction()
  }

  // MARK: - Workspace Creation

  /// Creates a new workspace
  func createWorkspace(name: String) throws -> XCWorkspace {
    // Validate user input for security
    let validatedWorkspaceName = try SecurityUtils.validateString(name)

    let workspacePath = workingDirectory + "\(validatedWorkspaceName).xcworkspace"

    // Check if workspace already exists
    if workspacePath.exists {
      throw ProjectError.operationFailed(
        "Workspace '\(validatedWorkspaceName)' already exists at \(workspacePath)")
    }

    // Create workspace with self-reference
    let workspace = XCWorkspace()

    // Add self-reference (current directory)
    let selfReference = XCWorkspaceDataFileRef(location: .group(""))
    workspace.data.children.append(.file(selfReference))

    // Save the workspace
    try workspace.write(path: workspacePath, override: false)

    print("✅ Created workspace: \(validatedWorkspaceName).xcworkspace")

    return workspace
  }

  /// Adds a project to an existing workspace
  func addProjectToWorkspace(
    workspaceName: String,
    projectPath: String
  ) throws {
    // Validate user inputs for security
    let validatedWorkspaceName = try SecurityUtils.validateString(workspaceName)
    let validatedProjectPath = try SecurityUtils.validatePath(projectPath)

    let workspacePath = findWorkspace(name: validatedWorkspaceName)

    guard workspacePath.exists else {
      throw ProjectError.operationFailed("Workspace '\(validatedWorkspaceName)' not found")
    }

    // Load existing workspace
    let workspace = try XCWorkspace(path: workspacePath)

    // Check if project already exists in workspace
    for child in workspace.data.children {
      if case .file(let ref) = child {
        if case .group(let path) = ref.location, path == validatedProjectPath {
          print("⚠️  Project '\(validatedProjectPath)' already exists in workspace")
          return
        }
      }
    }

    // Add project reference
    let projectRef = XCWorkspaceDataFileRef(location: .group(validatedProjectPath))
    workspace.data.children.append(.file(projectRef))

    // Save the workspace
    try workspace.write(path: workspacePath, override: true)

    print("✅ Added project '\(validatedProjectPath)' to workspace '\(validatedWorkspaceName)'")
  }

  /// Removes a project from a workspace
  func removeProjectFromWorkspace(
    workspaceName: String,
    projectPath: String
  ) throws {
    // Validate user inputs for security
    let validatedWorkspaceName = try SecurityUtils.validateString(workspaceName)
    let validatedProjectPath = try SecurityUtils.validatePath(projectPath)

    let workspacePath = findWorkspace(name: validatedWorkspaceName)

    guard workspacePath.exists else {
      throw ProjectError.operationFailed("Workspace '\(validatedWorkspaceName)' not found")
    }

    // Load existing workspace
    let workspace = try XCWorkspace(path: workspacePath)

    // Find and remove the project
    var found = false
    workspace.data.children.removeAll { child in
      if case .file(let ref) = child {
        if case .group(let path) = ref.location {
          // Use proper path comparison instead of fragile string matching
          let normalizedRefPath = (path as NSString).standardizingPath
          let normalizedProjectPath = (validatedProjectPath as NSString).standardizingPath

          // Check for exact match or if paths resolve to the same location
          if normalizedRefPath == normalizedProjectPath {
            found = true
            return true
          }

          // Also check if the last path component matches (for relative vs absolute paths)
          let refLastComponent = (normalizedRefPath as NSString).lastPathComponent
          let projectLastComponent = (normalizedProjectPath as NSString).lastPathComponent
          if refLastComponent == projectLastComponent && refLastComponent.hasSuffix(".xcodeproj") {
            found = true
            return true
          }
        }
      }
      return false
    }

    if !found {
      throw ProjectError.operationFailed("Project '\(validatedProjectPath)' not found in workspace")
    }

    // Save the workspace
    try workspace.write(path: workspacePath, override: true)

    print("✅ Removed project '\(validatedProjectPath)' from workspace '\(validatedWorkspaceName)'")
  }

  /// Lists all projects in a workspace
  func listWorkspaceProjects(workspaceName: String) throws -> [String] {
    // Validate user input for security
    let validatedWorkspaceName = try SecurityUtils.validateString(workspaceName)

    let workspacePath = findWorkspace(name: validatedWorkspaceName)

    guard workspacePath.exists else {
      throw ProjectError.workspaceNotFound(validatedWorkspaceName)
    }

    do {
      let workspace = try XCWorkspace(path: workspacePath)
      var projects: [String] = []

      for child in workspace.data.children {
        if case .file(let ref) = child {
          if case .group(let path) = ref.location {
            if !path.isEmpty {
              projects.append(path)
            }
          } else if case .absolute(let path) = ref.location {
            projects.append(path)
          } else if case .developer(let path) = ref.location {
            projects.append("Developer:\(path)")
          } else if case .container(let path) = ref.location {
            projects.append("Container:\(path)")
          }
        }
      }

      return projects
    } catch {
      throw ProjectError.workspaceLoadFailed(validatedWorkspaceName, error)
    }
  }

  // MARK: - Cross-Project Support

  /// Adds a reference to an external project
  func addProjectReference(
    to xcodeproj: XcodeProj,
    externalProjectPath: String,
    groupPath: String? = nil
  ) throws {
    // Validate user inputs for security
    let validatedExternalProjectPath = try SecurityUtils.validatePath(externalProjectPath)
    let validatedGroupPath = try groupPath.map { try SecurityUtils.validateString($0) }

    let pbxproj = xcodeproj.pbxproj

    // Find or create the group
    let group: PBXGroup
    if let groupPath = validatedGroupPath {
      guard let existingGroup = findGroup(named: groupPath, in: pbxproj.groups) else {
        throw ProjectError.groupNotFound(groupPath)
      }
      group = existingGroup
    } else {
      guard let mainGroup = pbxproj.rootObject?.mainGroup ?? pbxproj.groups.first else {
        throw ProjectError.operationFailed("No main group or root groups found in project")
      }
      group = mainGroup
    }

    // Create file reference for the external project
    let projectName = Path(validatedExternalProjectPath).lastComponent
    let fileRef = PBXFileReference(
      sourceTree: .group,
      name: projectName,
      lastKnownFileType: "wrapper.pb-project",
      path: validatedExternalProjectPath
    )

    // Add to project
    pbxproj.add(object: fileRef)
    group.children.append(fileRef)

    // Create container item proxy for the external project
    let containerProxy = PBXContainerItemProxy(
      containerPortal: .fileReference(fileRef),
      remoteGlobalID: nil,  // Will be set when adding specific target dependencies
      proxyType: .reference,
      remoteInfo: nil
    )
    pbxproj.add(object: containerProxy)

    print("✅ Added reference to external project: \(projectName)")
  }

  /// Adds a cross-project target dependency
  func addCrossProjectDependency(
    to xcodeproj: XcodeProj,
    targetName: String,
    externalProjectPath: String,
    externalTargetName: String
  ) throws {
    // Validate user inputs for security
    let validatedTargetName = try SecurityUtils.validateString(targetName)
    let validatedExternalProjectPath = try SecurityUtils.validatePath(externalProjectPath)
    let validatedExternalTargetName = try SecurityUtils.validateString(externalTargetName)

    let pbxproj = xcodeproj.pbxproj

    // Find the target
    guard let target = pbxproj.targets(named: validatedTargetName).first else {
      throw ProjectError.targetNotFound(validatedTargetName)
    }

    // Find the external project reference
    let projectName = Path(validatedExternalProjectPath).lastComponent
    guard
      let projectRef = pbxproj.fileReferences.first(where: {
        $0.path == validatedExternalProjectPath || $0.name == projectName
      })
    else {
      throw ProjectError.operationFailed(
        "External project '\(projectName)' not found. Add project reference first.")
    }

    // Create container item proxy for the dependency
    let containerProxy = PBXContainerItemProxy(
      containerPortal: .fileReference(projectRef),
      remoteGlobalID: nil,  // Would need to be extracted from external project
      proxyType: .nativeTarget,
      remoteInfo: validatedExternalTargetName
    )
    pbxproj.add(object: containerProxy)

    // Create target dependency
    let targetDependency = PBXTargetDependency(
      name: validatedExternalTargetName,
      targetProxy: containerProxy
    )
    pbxproj.add(object: targetDependency)

    // Add to target's dependencies
    target.dependencies.append(targetDependency)

    print(
      "✅ Added cross-project dependency: \(validatedTargetName) -> \(validatedExternalProjectPath):\(validatedExternalTargetName)"
    )
  }

  // MARK: - Private Helpers

  private func findWorkspace(name: String) -> Path {
    // Note: This is a private method, so the name should already be validated by the calling methods
    let workspaceName = name.hasSuffix(".xcworkspace") ? name : "\(name).xcworkspace"
    return workingDirectory + workspaceName
  }

  private func findGroup(named path: String, in groups: [PBXGroup]) -> PBXGroup? {
    let components = path.split(separator: "/").map(String.init)

    guard !components.isEmpty else {
      return groups.first
    }

    var currentGroups = groups
    var currentGroup: PBXGroup?

    for component in components {
      currentGroup = currentGroups.first { group in
        group.name == component || group.path == component
      }

      guard let group = currentGroup else {
        return nil
      }

      currentGroups = group.children.compactMap { $0 as? PBXGroup }
    }

    return currentGroup
  }
}
