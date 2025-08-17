//
// ProjectValidator.swift
// xcodeproj-cli
//
// Project validation and cleanup functionality
//

import Foundation
@preconcurrency import PathKit
@preconcurrency import XcodeProj

/// Validates Xcode project structure and provides cleanup functionality
@MainActor
class ProjectValidator {
  private let pbxproj: PBXProj
  private let projectPath: Path
  private lazy var buildPhaseManager = BuildPhaseManager(pbxproj: pbxproj)

  init(pbxproj: PBXProj, projectPath: Path) {
    self.pbxproj = pbxproj
    self.projectPath = projectPath
  }

  /// Basic validation that returns a list of issues
  func validate() -> [String] {
    var issues: [String] = []

    // Check for orphaned file references
    for fileRef in pbxproj.fileReferences {
      var found = false
      for group in pbxproj.groups {
        if group.children.contains(where: { $0 === fileRef }) {
          found = true
          break
        }
      }
      if !found {
        issues.append("Orphaned file reference: \(fileRef.path ?? fileRef.name ?? "unknown")")
      }
    }

    // Check for missing build files
    for target in pbxproj.nativeTargets {
      guard let sourcePhase = XcodeProjectHelpers.sourceBuildPhase(for: target) else { continue }
      for buildFileRef in sourcePhase.files ?? [] {
        if buildFileRef.file == nil {
          issues.append("Missing file reference in target: \(target.name)")
        }
      }
    }

    return issues
  }

  /// Comprehensive validation that lists all invalid file references
  func listInvalidReferences() {
    print("🔍 Checking for invalid file and folder references...")

    var invalidRefs: [(group: String, path: String, issue: String)] = []
    let fileManager = FileManager.default
    let projectDir = projectPath.parent()

    // Check each file reference recursively
    do {
      guard let rootGroup = try pbxproj.rootGroup() else {
        print("⚠️  Unable to access project root group: project may be corrupted")
        return
      }
      checkFilesInGroup(
        rootGroup, groupPath: "", projectDir: projectDir, fileManager: fileManager,
        invalidRefs: &invalidRefs)
    } catch {
      print("⚠️  Unable to access project root group: \(error)")
    }

    // Report results
    if invalidRefs.isEmpty {
      print("✅ All file references are valid")
    } else {
      print("❌ Found \(invalidRefs.count) invalid file reference(s):\n")
      for ref in invalidRefs {
        print("  Group: \(ref.group.isEmpty ? "Root" : ref.group)")
        print("  File:  \(ref.path)")
        print("  Issue: \(ref.issue)")
        print("")
      }
    }
  }

  /// Remove invalid file references from the project
  func removeInvalidReferences() {
    print("🔍 Checking for invalid file and folder references to remove...")

    var removedCount = 0
    let fileManager = FileManager.default
    let projectDir = projectPath.parent()

    // Collect invalid references to remove
    var refsToRemove: [PBXFileReference] = []
    var groupsToRemove: [PBXGroup] = []

    // Start checking from root group
    do {
      guard let rootGroup = try pbxproj.rootGroup() else {
        print("⚠️  Unable to access project root group: project may be corrupted")
        return
      }
      findInvalidFilesInGroup(
        rootGroup, projectDir: projectDir, fileManager: fileManager, refsToRemove: &refsToRemove,
        groupsToRemove: &groupsToRemove)
    } catch {
      print("⚠️  Unable to access project root group: \(error)")
    }

    // Remove invalid groups
    for groupToRemove in groupsToRemove {
      // Remove from parent groups
      for group in pbxproj.groups {
        group.children.removeAll { $0 === groupToRemove }
      }
      removedCount += 1
    }

    // Remove invalid file references
    for fileRef in refsToRemove {
      removeFileReference(fileRef)
      removedCount += 1
    }

    // Report results
    if removedCount == 0 {
      print("✅ No invalid references found to remove")
    } else {
      print("✅ Removed \(removedCount) invalid reference(s)")
    }
  }

  // MARK: - Private Helper Methods

  private func resolveAbsolutePath(
    for fileRef: PBXFileReference, in group: PBXGroup?, projectDir: Path
  ) -> Path? {
    guard let filePath = fileRef.path ?? fileRef.name else { return nil }

    var basePath = projectDir

    if let sourceTree = fileRef.sourceTree {
      switch sourceTree {
      case .absolute:
        return Path(filePath)
      case .group:
        if let group = group {
          basePath = basePath + buildGroupPath(from: group)
        }
      case .sourceRoot:
        basePath = projectDir
      default:
        break
      }
    }

    return basePath + Path(filePath)
  }

  private func resolveAbsolutePathForGroup(_ group: PBXGroup, projectDir: Path) -> Path? {
    guard let groupPath = group.path, !groupPath.isEmpty else { return nil }

    let basePath = projectDir + buildGroupPath(from: group)
    return basePath
  }

  private func buildGroupPath(from group: PBXGroup) -> Path {
    var pathComponents: [String] = []
    var currentGroup: PBXGroup? = group

    while let g = currentGroup {
      if let path = g.path, !path.isEmpty {
        pathComponents.insert(path, at: 0)
      }
      currentGroup = findParentGroup(of: g)
    }

    var result = Path("")
    for component in pathComponents {
      result = result + Path(component)
    }
    return result
  }

  private func findParentGroup(of group: PBXGroup) -> PBXGroup? {
    return pbxproj.groups.first { parent in
      parent.children.contains { $0 === group }
    }
  }

  private func checkFilesInGroup(
    _ group: PBXGroup, groupPath: String, projectDir: Path, fileManager: FileManager,
    invalidRefs: inout [(group: String, path: String, issue: String)]
  ) {
    // Check if the group itself represents a folder that should exist
    if let absoluteGroupPath = resolveAbsolutePathForGroup(group, projectDir: projectDir) {
      let pathString = absoluteGroupPath.string
      if !fileManager.fileExists(atPath: pathString) {
        let displayPath = group.path ?? group.name ?? "unknown"
        invalidRefs.append(
          (
            group: groupPath.isEmpty ? "Root" : groupPath, path: displayPath,
            issue: "Folder not found at: \(pathString)"
          ))
      } else {
        var isDirectory: ObjCBool = false
        fileManager.fileExists(atPath: pathString, isDirectory: &isDirectory)
        if !isDirectory.boolValue {
          let displayPath = group.path ?? group.name ?? "unknown"
          invalidRefs.append(
            (
              group: groupPath.isEmpty ? "Root" : groupPath, path: displayPath,
              issue: "Expected folder but found file at: \(pathString)"
            ))
        }
      }
    }

    // Check children
    for child in group.children {
      if let fileRef = child as? PBXFileReference {
        checkFileReference(
          fileRef, in: group, groupPath: groupPath, projectDir: projectDir,
          fileManager: fileManager, invalidRefs: &invalidRefs)
      } else if let subgroup = child as? PBXGroup {
        let subgroupName = subgroup.name ?? subgroup.path ?? "unnamed"
        let newPath = groupPath.isEmpty ? subgroupName : "\(groupPath)/\(subgroupName)"
        checkFilesInGroup(
          subgroup, groupPath: newPath, projectDir: projectDir, fileManager: fileManager,
          invalidRefs: &invalidRefs)
      }
    }
  }

  private func checkFileReference(
    _ fileRef: PBXFileReference, in group: PBXGroup, groupPath: String, projectDir: Path,
    fileManager: FileManager, invalidRefs: inout [(group: String, path: String, issue: String)]
  ) {
    guard let absolutePath = resolveAbsolutePath(for: fileRef, in: group, projectDir: projectDir)
    else { return }

    let pathString = absolutePath.string

    if !fileManager.fileExists(atPath: pathString) {
      let displayPath = fileRef.path ?? fileRef.name ?? "unknown"
      invalidRefs.append(
        (group: groupPath, path: displayPath, issue: "File not found at: \(pathString)"))
    } else {
      var isDirectory: ObjCBool = false
      fileManager.fileExists(atPath: pathString, isDirectory: &isDirectory)

      let isFolder =
        fileRef.lastKnownFileType == "folder" || fileRef.lastKnownFileType == "folder.assetcatalog"
        || fileRef.lastKnownFileType == "wrapper.framework"

      if isFolder && !isDirectory.boolValue {
        invalidRefs.append(
          (
            group: groupPath, path: fileRef.path ?? fileRef.name ?? "unknown",
            issue: "Expected directory but found file at: \(pathString)"
          ))
      } else if !isFolder && isDirectory.boolValue && fileRef.lastKnownFileType != nil {
        invalidRefs.append(
          (
            group: groupPath, path: fileRef.path ?? fileRef.name ?? "unknown",
            issue: "Expected file but found directory at: \(pathString)"
          ))
      }
    }
  }

  private func findInvalidFilesInGroup(
    _ group: PBXGroup, projectDir: Path, fileManager: FileManager,
    refsToRemove: inout [PBXFileReference], groupsToRemove: inout [PBXGroup]
  ) {
    // Check if the group itself represents a folder that should exist
    if let absoluteGroupPath = resolveAbsolutePathForGroup(group, projectDir: projectDir) {
      let pathString = absoluteGroupPath.string
      if !fileManager.fileExists(atPath: pathString) {
        groupsToRemove.append(group)
        let displayPath = group.path ?? group.name ?? "unknown"
        print("  ❌ Will remove folder: \(displayPath)")
      } else {
        var isDirectory: ObjCBool = false
        fileManager.fileExists(atPath: pathString, isDirectory: &isDirectory)
        if !isDirectory.boolValue {
          groupsToRemove.append(group)
          let displayPath = group.path ?? group.name ?? "unknown"
          print("  ❌ Will remove folder: \(displayPath) (not a directory)")
        }
      }
    }

    // Check children
    for child in group.children {
      if let fileRef = child as? PBXFileReference {
        if shouldRemoveFileReference(
          fileRef, in: group, projectDir: projectDir, fileManager: fileManager)
        {
          refsToRemove.append(fileRef)
          let displayPath = fileRef.path ?? fileRef.name ?? "unknown"
          print("  ❌ Will remove: \(displayPath)")
        }
      } else if let subgroup = child as? PBXGroup {
        findInvalidFilesInGroup(
          subgroup, projectDir: projectDir, fileManager: fileManager, refsToRemove: &refsToRemove,
          groupsToRemove: &groupsToRemove)
      }
    }
  }

  private func shouldRemoveFileReference(
    _ fileRef: PBXFileReference, in group: PBXGroup, projectDir: Path, fileManager: FileManager
  ) -> Bool {
    guard let absolutePath = resolveAbsolutePath(for: fileRef, in: group, projectDir: projectDir)
    else { return false }

    let pathString = absolutePath.string

    if !fileManager.fileExists(atPath: pathString) {
      return true
    }

    var isDirectory: ObjCBool = false
    fileManager.fileExists(atPath: pathString, isDirectory: &isDirectory)

    let isFolder =
      fileRef.lastKnownFileType == "folder" || fileRef.lastKnownFileType == "folder.assetcatalog"
      || fileRef.lastKnownFileType == "wrapper.framework"

    return (isFolder && !isDirectory.boolValue)
      || (!isFolder && isDirectory.boolValue && fileRef.lastKnownFileType != nil)
  }

  private func removeFileReference(_ fileRef: PBXFileReference) {
    // Remove from all groups
    for group in pbxproj.groups {
      group.children.removeAll { $0 === fileRef }
    }

    // Remove from all build phases and delete build files
    let buildFilesToDelete = buildPhaseManager.findBuildFiles(for: fileRef)
    buildPhaseManager.removeBuildFiles(for: fileRef)

    // Delete all collected build files from the project
    for buildFile in buildFilesToDelete {
      pbxproj.delete(object: buildFile)
    }

    // Remove from project
    pbxproj.delete(object: fileRef)
  }

  // MARK: - Product Reference Validation

  /// Find orphaned file references not contained in any group
  func findOrphanedFileReferences() -> [PBXFileReference] {
    var orphanedRefs: [PBXFileReference] = []

    for fileRef in pbxproj.fileReferences {
      var found = false
      for group in pbxproj.groups {
        if group.children.contains(where: { $0 === fileRef }) {
          found = true
          break
        }
      }
      if !found {
        orphanedRefs.append(fileRef)
      }
    }

    return orphanedRefs
  }

  /// Remove orphaned file references from the project
  func removeOrphanedFileReferences() throws {
    let orphaned = findOrphanedFileReferences()
    for fileRef in orphaned {
      removeFileReference(fileRef)
    }
  }

  /// Validate product references for all targets
  func validateProductReferences() -> [String] {
    var issues: [String] = []

    // Check if Products group exists
    if pbxproj.rootObject?.productsGroup == nil {
      issues.append("Products group is missing from project")
    }

    // TODO: Add product reference validation when productReference is accessible
    issues.append("Product reference validation requires XcodeProj library update")

    return issues
  }

  /// Find targets that are missing product references
  func findMissingProductReferences() -> [PBXNativeTarget] {
    // TODO: Implement when productReference is accessible
    return pbxproj.nativeTargets
  }

  /// Find orphaned product references in Products group
  func findOrphanedProductReferences() -> [PBXFileReference] {
    guard let productsGroup = pbxproj.rootObject?.productsGroup else { return [] }

    // Since we can't access productReference, return all products as potentially orphaned
    var orphaned: [PBXFileReference] = []

    for child in productsGroup.children {
      if let fileRef = child as? PBXFileReference {
        orphaned.append(fileRef)
      }
    }

    return orphaned
  }
}
