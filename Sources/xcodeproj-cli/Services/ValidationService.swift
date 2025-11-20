//
// ValidationService.swift
// xcodeproj-cli
//

import Foundation
@preconcurrency import PathKit
@preconcurrency import XcodeProj

/// Service for validating and fixing project references
@MainActor
final class ValidationService {
  private let pbxproj: PBXProj
  private let buildPhaseManager: BuildPhaseManager
  private let projectPath: Path

  init(pbxproj: PBXProj, buildPhaseManager: BuildPhaseManager, projectPath: Path) {
    self.pbxproj = pbxproj
    self.buildPhaseManager = buildPhaseManager
    self.projectPath = projectPath
  }

  // MARK: - Validation Methods

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
      guard let sourcePhase = sourceBuildPhase(for: target) else { continue }
      for buildFileRef in sourcePhase.files ?? [] {
        if buildFileRef.file == nil {
          issues.append("Missing file reference in target: \(target.name)")
        }
      }
    }

    return issues
  }

  func listInvalidReferences() {
    print("🔍 Checking for invalid file and folder references...")

    var invalidRefs: [(group: String, path: String, issue: String)] = []
    let pathResolver = PathResolver(pbxproj: pbxproj, projectDir: projectPath.parent())

    // Check each file reference
    func checkFilesInGroup(_ group: PBXGroup, groupPath: String) {
      // First check if the group itself represents a folder that should exist
      if let issue = pathResolver.validateGroup(group) {
        let displayPath = group.path ?? group.name ?? "unknown"
        invalidRefs.append(
          (
            group: groupPath.isEmpty ? "Root" : groupPath,
            path: displayPath,
            issue: issue
          ))
      }

      // Then check children
      for child in group.children {
        if let fileRef = child as? PBXFileReference {
          if let issue = pathResolver.validateFileReference(fileRef, in: group) {
            let displayPath = fileRef.path ?? fileRef.name ?? "unknown"
            invalidRefs.append(
              (
                group: groupPath,
                path: displayPath,
                issue: issue
              ))
          }
        } else if let subgroup = child as? PBXGroup {
          let subgroupName = subgroup.name ?? subgroup.path ?? "unnamed"
          let newPath = groupPath.isEmpty ? subgroupName : "\(groupPath)/\(subgroupName)"
          checkFilesInGroup(subgroup, groupPath: newPath)
        }
      }
    }

    // Start checking from root group
    if let rootGroup = pbxproj.rootObject?.mainGroup {
      checkFilesInGroup(rootGroup, groupPath: "")
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

  func removeInvalidReferences() {
    print("🔍 Checking for invalid file and folder references to remove...")

    var removedCount = 0
    let pathResolver = PathResolver(pbxproj: pbxproj, projectDir: projectPath.parent())

    // Collect invalid references to remove
    var refsToRemove: [PBXFileReference] = []
    var groupsToRemove: [PBXGroup] = []

    func findInvalidFilesInGroup(_ group: PBXGroup) {
      // First check if the group itself represents a folder that should exist
      if pathResolver.validateGroup(group) != nil {
        groupsToRemove.append(group)
        let displayPath = group.path ?? group.name ?? "unknown"
        print("  ❌ Will remove folder: \(displayPath)")
      }

      // Then check children
      for child in group.children {
        if let fileRef = child as? PBXFileReference {
          if pathResolver.validateFileReference(fileRef, in: group) != nil {
            refsToRemove.append(fileRef)
            let displayPath = fileRef.path ?? fileRef.name ?? "unknown"
            print("  ❌ Will remove: \(displayPath)")
          }
        } else if let subgroup = child as? PBXGroup {
          findInvalidFilesInGroup(subgroup)
        }
      }
    }

    // Start checking from root group
    if let rootGroup = pbxproj.rootObject?.mainGroup {
      findInvalidFilesInGroup(rootGroup)
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
      // Remove from all groups
      for group in pbxproj.groups {
        group.children.removeAll { $0 === fileRef }
      }

      // Remove from all build phases
      buildPhaseManager.removeBuildFiles(for: fileRef)

      // Remove build files that reference this file
      let buildFilesToRemove = pbxproj.buildFiles.filter { $0.file === fileRef }
      for buildFile in buildFilesToRemove {
        pbxproj.delete(object: buildFile)
      }

      // Remove from project
      pbxproj.delete(object: fileRef)
      removedCount += 1
    }

    // Report results
    if removedCount == 0 {
      print("✅ No invalid references to remove")
    } else {
      print("✅ Removed \(removedCount) invalid file reference(s)")
    }
  }
}
