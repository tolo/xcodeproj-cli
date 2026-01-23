//
// GroupService.swift
// xcodeproj-cli
//

import Foundation
@preconcurrency import PathKit
@preconcurrency import XcodeProj

/// Service for group management in Xcode projects
///
/// Thread Safety:
/// - All operations are @MainActor isolated
/// - Cache access is single-threaded via MainActor
/// - No explicit synchronization needed for cache operations
/// - Not safe to call from background threads
///
/// Performance:
/// - Multi-level caching with O(1) group lookups
/// - Cache invalidation is O(n) for subgroup hierarchies
/// - Suitable for projects with <1000 groups
/// - For larger projects, consider hierarchical cache structure
@MainActor
final class GroupService {
  private let pbxproj: PBXProj
  private let cacheManager: CacheManager
  private let buildPhaseManager: BuildPhaseManager
  private let projectPath: Path
  private let profiler: PerformanceProfiler?

  init(
    pbxproj: PBXProj,
    cacheManager: CacheManager,
    buildPhaseManager: BuildPhaseManager,
    projectPath: Path,
    profiler: PerformanceProfiler? = nil
  ) {
    self.pbxproj = pbxproj
    self.cacheManager = cacheManager
    self.buildPhaseManager = buildPhaseManager
    self.projectPath = projectPath
    self.profiler = profiler
  }

  // MARK: - Group Management

  func ensureGroupHierarchy(_ path: String) throws -> PBXGroup? {
    return try profiler?.measureOperation("ensureGroupHierarchy-\(path)") {
      return try _ensureGroupHierarchy(path)
    } ?? _ensureGroupHierarchy(path)
  }

  private func _ensureGroupHierarchy(_ path: String) throws -> PBXGroup? {
    // Validate input
    let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      throw ProjectError.invalidArguments("Group path cannot be empty")
    }

    // Check for invalid patterns
    let components = trimmed.split(separator: "/").map(String.init)
    guard !components.isEmpty && components.allSatisfy({ !$0.isEmpty }) else {
      throw ProjectError.invalidArguments("Invalid group path: '\(path)'")
    }

    // Check cache first
    if let cachedGroup = cacheManager.getGroup(trimmed) {
      return cachedGroup
    }

    guard let mainGroup = pbxproj.rootObject?.mainGroup else {
      print("⚠️  No main group found in project")
      return nil
    }

    var currentGroup = mainGroup
    var currentPath = ""
    var createdGroups: [String] = []  // Track created groups for cache invalidation

    for component in components {
      currentPath = currentPath.isEmpty ? component : "\(currentPath)/\(component)"

      // Check cache for this path segment
      if let cachedSegment = cacheManager.getGroup(currentPath) {
        currentGroup = cachedSegment
        continue
      }

      // Look for existing child group
      if let existingGroup = currentGroup.children.compactMap({ $0 as? PBXGroup })
        .first(where: { $0.name == component || $0.path == component })
      {
        currentGroup = existingGroup
      } else {
        // Check for ANY child (file or group) with this name to prevent corruption
        let conflictingChild = currentGroup.children.first { child in
          if let file = child as? PBXFileReference {
            let fileName = file.name ?? file.path
            guard let fileName = fileName, !fileName.isEmpty else { return false }

            // Check exact match with full filename
            if fileName == component {
              return true
            }

            // Check match with file stem (name without extension)
            // Note: deletingPathExtension only removes the last extension
            // "file.test.swift" → stem "file.test" (not "file")
            // This means "file.test" group will conflict, but "file" won't
            let fileStem = (fileName as NSString).deletingPathExtension
            if fileStem == component {
              return true
            }

            return false
          } else if let variantGroup = child as? PBXVariantGroup {
            return variantGroup.name == component
          }
          return false
        }

        if let conflict = conflictingChild {
          let conflictType = conflict is PBXFileReference ? "file" : "group"
          let conflictName =
            (conflict as? PBXFileReference)?.name
            ?? (conflict as? PBXFileReference)?.path
            ?? (conflict as? PBXVariantGroup)?.name
            ?? "unknown"
          throw ProjectError.operationFailed(
            """
            Cannot create group '\(component)': a \(conflictType) with name '\(conflictName)' already exists.

            Current path: \(currentPath.isEmpty ? "root" : currentPath)
            Attempted to create: \(path)

            Tip: Choose a different group name or restructure your hierarchy.
            """
          )
        }

        // Create new group
        let newGroup = PBXGroup(
          children: [],
          sourceTree: .group,
          name: component,
          path: component
        )

        pbxproj.add(object: newGroup)
        createdGroups.append(currentPath)  // Track immediately after add for robustness
        currentGroup.children.append(newGroup)
        currentGroup = newGroup

        print("📁 Created group: \(component)")
      }
    }

    // Invalidate cache only after ALL operations succeed
    for groupPath in createdGroups {
      cacheManager.invalidateGroup(groupPath)
    }

    return currentGroup
  }

  // Create multiple groups at once
  func createGroups(_ groupPaths: [String]) throws {
    for groupPath in groupPaths {
      _ = try ensureGroupHierarchy(groupPath)
    }
  }

  // Enhanced group finding that supports nested paths
  func findGroupAtPath(_ path: String) -> PBXGroup? {
    guard let mainGroup = pbxproj.rootObject?.mainGroup else { return nil }

    if path.isEmpty {
      return mainGroup
    }

    return XcodeProjectHelpers.findGroupByPath(path, in: pbxproj.groups, rootGroup: mainGroup)
  }

  /// Finds a group by either simple name or hierarchical path
  /// - Parameter identifier: Simple name (e.g., "Models") or path (e.g., "App/Source/Models")
  /// - Returns: Found group or nil
  /// - Note: No fallback behavior - hierarchical paths must resolve exactly or nil is returned
  func findGroupByNameOrPath(_ identifier: String) -> PBXGroup? {
    // Check if identifier contains slashes (path)
    if identifier.contains("/") {
      // Treat as hierarchical path - must resolve exactly
      return findGroupAtPath(identifier)
    } else {
      // Simple name lookup
      return XcodeProjectHelpers.findGroup(named: identifier, in: pbxproj.groups)
    }
  }

  func removeGroup(_ groupPath: String) throws {
    // First try to find it as a regular group (supports both simple names and hierarchical paths)
    if let group = findGroupByNameOrPath(groupPath) {
      // Check if this is a special system group that shouldn't be removed
      if group === pbxproj.rootObject?.productsGroup {
        throw ProjectError.operationFailed("Cannot remove Products group - it's a system group")
      }
      if group === pbxproj.rootObject?.mainGroup {
        throw ProjectError.operationFailed(
          "Cannot remove '\(groupPath)' - it is the main project group. This would corrupt the project structure."
        )
      }

      removeGroupHierarchy(group)
      print("✅ Removed group '\(groupPath)'")
      return
    }

    // Try to find it as a file reference (folder reference)
    if let folderRef = pbxproj.fileReferences.first(where: {
      ($0.path == groupPath || $0.name == groupPath)
        && ($0.lastKnownFileType == "folder" || $0.lastKnownFileType == "folder.assetcatalog")
    }) {
      removeFolderReference(folderRef)
      print("✅ Removed folder reference '\(groupPath)'")
      return
    }

    // Try to find it as a synchronized folder
    if let syncGroup = pbxproj.fileSystemSynchronizedRootGroups.first(where: {
      $0.path == groupPath || $0.name == groupPath
    }) {
      removeSynchronizedFolder(syncGroup)
      print("✅ Removed synchronized folder '\(groupPath)'")
      return
    }

    throw ProjectError.groupNotFound(groupPath)
  }

  // MARK: - Group Removal Helper Methods

  /// Contains collected contents from a group hierarchy
  private struct GroupContents {
    let filesToRemove: [PBXFileReference]
    let groupsToRemove: [PBXGroup]
    let variantGroupsToRemove: [PBXVariantGroup]
  }

  /// Recursively collects all files and subgroups from a group hierarchy
  private func collectGroupContents(from group: PBXGroup) -> GroupContents {
    var filesToRemove: [PBXFileReference] = []
    var groupsToRemove: [PBXGroup] = [group]
    var variantGroupsToRemove: [PBXVariantGroup] = []

    func collectFromGroup(_ group: PBXGroup) {
      for child in group.children {
        if let fileRef = child as? PBXFileReference {
          filesToRemove.append(fileRef)
        } else if let variantGroup = child as? PBXVariantGroup {
          variantGroupsToRemove.append(variantGroup)
          // Collect files from variant group
          for variantChild in variantGroup.children {
            if let variantFileRef = variantChild as? PBXFileReference {
              filesToRemove.append(variantFileRef)
            }
          }
        } else if let subgroup = child as? PBXGroup {
          groupsToRemove.append(subgroup)
          collectFromGroup(subgroup)
        }
      }
    }

    collectFromGroup(group)

    return GroupContents(
      filesToRemove: filesToRemove,
      groupsToRemove: groupsToRemove,
      variantGroupsToRemove: variantGroupsToRemove
    )
  }

  /// Removes file references from all build phases using BuildPhaseManager
  private func removeFilesFromBuildPhases(_ files: [PBXFileReference]) {
    // Collect all build files that need to be removed
    // Using Array instead of Set to avoid crashes with duplicate PBXBuildFile elements (XcodeProj 9.4.3 bug)
    // Uses ObjectIdentifier for O(1) duplicate detection performance
    var buildFilesToDelete: [PBXBuildFile] = []
    var seen = Set<ObjectIdentifier>()

    for fileRef in files {
      let foundBuildFiles = buildPhaseManager.findBuildFiles(for: fileRef)
      for buildFile in foundBuildFiles {
        let id = ObjectIdentifier(buildFile)
        if !seen.contains(id) {
          seen.insert(id)
          buildFilesToDelete.append(buildFile)
        }
      }
    }

    // Remove build files from their respective build phases
    buildPhaseManager.removeBuildFiles { buildFile in
      buildFilesToDelete.contains(where: { $0 === buildFile })
    }

    // Delete all collected build files from the project
    for buildFile in buildFilesToDelete {
      pbxproj.delete(object: buildFile)
    }
  }

  /// Deletes the group and all its collected contents from the project
  private func deleteGroupAndContents(_ group: PBXGroup, contents: GroupContents) {
    // Remove file references from project
    for fileRef in contents.filesToRemove {
      pbxproj.delete(object: fileRef)
    }

    // Remove variant groups from project
    for variantGroup in contents.variantGroupsToRemove {
      pbxproj.delete(object: variantGroup)
    }

    // Remove the group from its parent (including main project group)
    for parentGroup in pbxproj.groups {
      parentGroup.children.removeAll { $0 === group }
    }

    // Also check if the group is in the main project's mainGroup
    if let mainGroup = pbxproj.rootObject?.mainGroup {
      mainGroup.children.removeAll { $0 === group }
    }

    // Remove all groups from project
    for groupToRemove in contents.groupsToRemove {
      pbxproj.delete(object: groupToRemove)
    }
  }

  /// Removes a group hierarchy and all its contents from the project
  private func removeGroupHierarchy(_ group: PBXGroup) {
    // Step 1: Collect all contents from the group hierarchy
    let contents = collectGroupContents(from: group)

    // Step 2: Remove files from build phases
    removeFilesFromBuildPhases(contents.filesToRemove)

    // Step 3: Delete the group and all its contents
    deleteGroupAndContents(group, contents: contents)
  }

  private func removeFolderReference(_ folderRef: PBXFileReference) {
    // Collect all build files that reference this folder
    let buildFilesToDelete = buildPhaseManager.findBuildFiles(for: folderRef)

    // Remove from all groups
    for group in pbxproj.groups {
      group.children.removeAll { $0 === folderRef }
    }

    // Remove build files from build phases
    // Use identity comparison to match the fix pattern and avoid Set crashes
    buildPhaseManager.removeBuildFiles { buildFile in
      buildFilesToDelete.contains(where: { $0 === buildFile })
    }

    // Delete all collected build files from the project
    for buildFile in buildFilesToDelete {
      pbxproj.delete(object: buildFile)
    }

    // Remove the folder reference from project
    pbxproj.delete(object: folderRef)
  }

  private func removeSynchronizedFolder(_ syncGroup: PBXFileSystemSynchronizedRootGroup) {
    // Remove from parent groups
    for group in pbxproj.groups {
      group.children.removeAll { $0 === syncGroup }
    }

    // Remove from build phases if needed
    for target in pbxproj.nativeTargets {
      // Remove from build phase membership exceptions if present
      for phase in target.buildPhases {
        if let sourcePhase = phase as? PBXSourcesBuildPhase {
          sourcePhase.files?.removeAll { file in
            // Check if this build file is related to the sync group
            if let fileRef = file.file as? PBXFileSystemSynchronizedRootGroup {
              return fileRef === syncGroup
            }
            return false
          }
        }
      }
    }

    // Remove the synchronized group from project
    pbxproj.delete(object: syncGroup)
  }

  func removeFolder(_ folderPath: String) throws {
    // Deprecated: This function now just calls removeGroup for consistency
    // Kept for backward compatibility
    try removeGroup(folderPath)
  }
}
