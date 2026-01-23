//
// TreeDisplayService.swift
// xcodeproj-cli
//

import Foundation
@preconcurrency import PathKit
@preconcurrency import XcodeProj

/// Service for displaying project structure as trees
@MainActor
final class TreeDisplayService {
  private let pbxproj: PBXProj
  private let projectPath: Path

  init(pbxproj: PBXProj, projectPath: Path) {
    self.pbxproj = pbxproj
    self.projectPath = projectPath
  }

  // MARK: - Tree Display Methods

  func listProjectTree() {
    if let rootGroup = pbxproj.rootObject?.mainGroup {
      let projectName = pbxproj.rootObject?.name ?? projectPath.lastComponentWithoutExtension
      print(projectName)

      // Process root group's children directly
      let children = rootGroup.children
      for (index, child) in children.enumerated() {
        let childIsLast = (index == children.count - 1)
        printTreeNode(child, prefix: "", isLast: childIsLast, parentPath: "")
      }
    } else {
      print("❌ No project structure found")
    }
  }

  func listTargetTree(targetName: String) throws {
    guard let target = pbxproj.nativeTargets.first(where: { $0.name == targetName }) else {
      throw ProjectError.targetNotFound(targetName)
    }

    print("📁 Files in target '\(targetName)':")

    // Collect all files from target's build phases
    var fileReferences: Set<PBXFileReference> = []
    var fileToGroup: [PBXFileReference: PBXGroup] = [:]

    // Collect files from all build phases
    for buildPhase in target.buildPhases {
      var phaseFiles: [PBXBuildFile] = []

      switch buildPhase {
      case let sourcesBuildPhase as PBXSourcesBuildPhase:
        phaseFiles = sourcesBuildPhase.files ?? []
      case let resourcesBuildPhase as PBXResourcesBuildPhase:
        phaseFiles = resourcesBuildPhase.files ?? []
      case let frameworksBuildPhase as PBXFrameworksBuildPhase:
        phaseFiles = frameworksBuildPhase.files ?? []
      case let copyFilesBuildPhase as PBXCopyFilesBuildPhase:
        phaseFiles = copyFilesBuildPhase.files ?? []
      default:
        continue
      }

      for buildFile in phaseFiles {
        if let fileRef = buildFile.file as? PBXFileReference {
          fileReferences.insert(fileRef)
        }
      }
    }

    // Find parent groups for files
    if let rootGroup = pbxproj.rootObject?.mainGroup {
      findParentGroups(for: Array(fileReferences), in: rootGroup, parentGroups: &fileToGroup)
    }

    // Build tree structure
    var tree: [String: [PBXFileReference]] = [:]
    for fileRef in fileReferences {
      let groupPath = buildGroupPath(for: fileRef, fileToGroup: fileToGroup)
      if tree[groupPath] == nil {
        tree[groupPath] = []
      }
      tree[groupPath]?.append(fileRef)
    }

    // Display tree
    let sortedPaths = tree.keys.sorted()
    for path in sortedPaths {
      if !path.isEmpty {
        print("📁 \(path)")
      }
      if let files = tree[path] {
        let sortedFiles = files.sorted {
          ($0.path ?? $0.name ?? "") < ($1.path ?? $1.name ?? "")
        }
        for file in sortedFiles {
          let prefix = path.isEmpty ? "" : "  "
          print("\(prefix)  - \(file.path ?? file.name ?? "unknown")")
        }
      }
    }

    if fileReferences.isEmpty {
      print("  (no files)")
    } else {
      print("\nTotal: \(fileReferences.count) file(s)")
    }
  }

  func listGroupsTree() {
    if let rootGroup = pbxproj.rootObject?.mainGroup {
      let projectName = pbxproj.rootObject?.name ?? projectPath.lastComponentWithoutExtension
      print(projectName)

      // Process root group's children directly, showing only groups
      let children = rootGroup.children
      let groupChildren = children.filter {
        $0 is PBXGroup || $0 is PBXFileSystemSynchronizedRootGroup
      }

      for (index, child) in groupChildren.enumerated() {
        let childIsLast = (index == groupChildren.count - 1)
        printGroupsOnly(child, prefix: "", isLast: childIsLast)
      }
    } else {
      print("❌ No project structure found")
    }
  }

  // MARK: - Private Helper Methods

  private func findParentGroups(
    for files: [PBXFileReference], in group: PBXGroup,
    parentGroups: inout [PBXFileReference: PBXGroup], currentPath: String = ""
  ) {
    let groupPath = currentPath.isEmpty ? (group.name ?? group.path ?? "") : currentPath

    for child in group.children {
      if let fileRef = child as? PBXFileReference, files.contains(fileRef) {
        parentGroups[fileRef] = group
      } else if let subgroup = child as? PBXGroup {
        let subPath =
          groupPath.isEmpty
          ? (subgroup.name ?? subgroup.path ?? "")
          : "\(groupPath)/\(subgroup.name ?? subgroup.path ?? "")"
        findParentGroups(
          for: files, in: subgroup, parentGroups: &parentGroups, currentPath: subPath)
      }
    }
  }

  private func buildGroupPath(for file: PBXFileReference, fileToGroup: [PBXFileReference: PBXGroup])
    -> String
  {
    var path: [String] = []
    var currentGroup = fileToGroup[file]

    while let group = currentGroup {
      if let name = group.name ?? group.path {
        path.insert(name, at: 0)
      }
      // Find parent group
      currentGroup = nil
      for potentialParent in pbxproj.groups {
        if potentialParent.children.contains(where: { $0 === group }) {
          currentGroup = potentialParent
          break
        }
      }
      // Don't include the root group
      if currentGroup === pbxproj.rootObject?.mainGroup {
        break
      }
    }

    return path.joined(separator: "/")
  }

  private func printGroupsOnly(_ element: PBXFileElement, prefix: String, isLast: Bool) {
    let connector = isLast ? "└── " : "├── "
    let continuation = isLast ? "    " : "│   "

    // Only process groups
    if let group = element as? PBXGroup {
      let name = group.name ?? group.path ?? "unknown"
      print("\(prefix)\(connector)\(name)")

      // Filter children to show only groups
      let groupChildren = group.children.filter {
        $0 is PBXGroup || $0 is PBXFileSystemSynchronizedRootGroup
      }

      for (index, child) in groupChildren.enumerated() {
        let childIsLast = (index == groupChildren.count - 1)
        printGroupsOnly(child, prefix: prefix + continuation, isLast: childIsLast)
      }
    } else if let syncGroup = element as? PBXFileSystemSynchronizedRootGroup {
      let name = syncGroup.name ?? syncGroup.path ?? "unknown"
      print("\(prefix)\(connector)\(name) [synchronized]")
    }
  }

  private func printTreeNode(
    _ element: PBXFileElement, prefix: String, isLast: Bool, parentPath: String
  ) {
    let connector = isLast ? "└── " : "├── "
    let continuation = isLast ? "    " : "│   "

    // Get display name
    let name = element.name ?? element.path ?? "unknown"

    // Determine if this is an actual file/folder reference or a virtual group
    let isFileReference = element is PBXFileReference
    let isSyncFolder = element is PBXFileSystemSynchronizedRootGroup

    // For actual file/folder references, show the path
    if isFileReference {
      if let fileRef = element as? PBXFileReference {
        // Build the full path for file references
        let elementPath = fileRef.path ?? fileRef.name ?? ""
        let fullPath: String
        if parentPath.isEmpty {
          fullPath = elementPath
        } else if elementPath.isEmpty {
          fullPath = parentPath
        } else {
          fullPath = "\(parentPath)/\(elementPath)"
        }

        // Check if it's a folder reference (blue folder in Xcode)
        let isFolderRef =
          fileRef.lastKnownFileType == "folder"
          || fileRef.lastKnownFileType == "folder.assetcatalog"
          || fileRef.lastKnownFileType == "wrapper.framework"

        if isFolderRef {
          print("\(prefix)\(connector)\(name) (\(fullPath)) [folder reference]")
        } else {
          print("\(prefix)\(connector)\(name) (\(fullPath))")
        }
      }
    } else if isSyncFolder {
      // Synchronized folders (Xcode 16+)
      if let syncGroup = element as? PBXFileSystemSynchronizedRootGroup {
        let elementPath = syncGroup.path ?? syncGroup.name ?? ""
        let fullPath: String
        if parentPath.isEmpty {
          fullPath = elementPath
        } else if elementPath.isEmpty {
          fullPath = parentPath
        } else {
          fullPath = "\(parentPath)/\(elementPath)"
        }
        print("\(prefix)\(connector)\(name) (\(fullPath)) [synchronized]")
      }
    } else {
      // Virtual groups - just show the name without path
      print("\(prefix)\(connector)\(name)")
    }

    // Build path for children (considering virtual groups)
    let childPath: String
    if let group = element as? PBXGroup {
      // For virtual groups, keep the parent path
      // For groups with a path, append it
      if let groupPath = group.path, !groupPath.isEmpty {
        childPath = parentPath.isEmpty ? groupPath : "\(parentPath)/\(groupPath)"
      } else {
        childPath = parentPath
      }
    } else if isFileReference {
      // File references don't have children, but just in case
      let elementPath = element.path ?? element.name ?? ""
      childPath = parentPath.isEmpty ? elementPath : "\(parentPath)/\(elementPath)"
    } else {
      childPath = parentPath
    }

    // Recurse for groups
    if let group = element as? PBXGroup {
      let children = group.children
      for (index, child) in children.enumerated() {
        let childIsLast = (index == children.count - 1)
        printTreeNode(
          child, prefix: prefix + continuation, isLast: childIsLast, parentPath: childPath)
      }
    }
  }
}
