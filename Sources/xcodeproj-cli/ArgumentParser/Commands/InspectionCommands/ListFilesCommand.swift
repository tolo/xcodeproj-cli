//
// ListFilesCommand.swift
// xcodeproj-cli
//
// ArgumentParser command for listing files in the project or a specific group
//

import ArgumentParser
import Foundation
@preconcurrency import XcodeProj

/// ArgumentParser command for listing files in the project or a specific group
struct ListFilesCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "list-files",
    abstract: "List files in the project or a specific group"
  )

  @OptionGroup var global: GlobalOptions

  @Argument(help: "Optional: specific group to list files from")
  var groupName: String?

  @Option(
    name: [.customLong("target"), .customShort("t")],
    help: "Optional: list only files in specified target")
  var target: String?

  @MainActor
  func run() async throws {
    let services = try ProjectServiceFactory.create(from: global, readOnly: true)
    let utility = services.utility

    // If target filter is specified, show files in that target
    if let targetName = target {
      try listFilesInTarget(targetName, utility: utility)
      return
    }

    if let name = groupName,
      let group = utility.findGroupByNameOrPath(name)
    {
      print("📁 Files in group '\(name)':")
      let fileCount = countFilesInGroup(group)
      if fileCount == 0 {
        print("  (no files in this group)")
      } else {
        listFilesInGroup(group)
      }
    } else if let name = groupName {
      throw ProjectError.groupNotFound(name)
    } else {
      print("📁 All files in project:")
      if let rootGroup = utility.pbxproj.rootObject?.mainGroup {
        listFilesInGroup(rootGroup)
      } else {
        print("❌ No project structure found")
      }
    }
  }

  private func countFilesInGroup(_ group: PBXGroup) -> Int {
    var count = 0
    for child in group.children {
      if child is PBXFileReference {
        count += 1
      } else if let subgroup = child as? PBXGroup {
        count += countFilesInGroup(subgroup)
      }
    }
    return count
  }

  private func listFilesInGroup(_ group: PBXGroup, indent: String = "") {
    for child in group.children {
      if let fileRef = child as? PBXFileReference {
        print("\(indent)- \(fileRef.path ?? fileRef.name ?? "unknown")")
      } else if let subgroup = child as? PBXGroup {
        print("\(indent)📁 \(subgroup.name ?? subgroup.path ?? "unknown")/")
        listFilesInGroup(subgroup, indent: indent + "  ")
      }
    }
  }

  @MainActor
  private func listFilesInTarget(_ targetName: String, utility: XcodeProjUtility) throws {
    guard let target = utility.pbxproj.nativeTargets.first(where: { $0.name == targetName }) else {
      throw ProjectError.targetNotFound(targetName)
    }

    print("📁 Files in target '\(targetName)':")

    var fileReferences: Set<PBXFileReference> = []

    // Collect files from all build phases
    for buildPhase in target.buildPhases {
      switch buildPhase {
      case let sourcesBuildPhase as PBXSourcesBuildPhase:
        if let files = sourcesBuildPhase.files {
          for buildFile in files {
            if let fileRef = buildFile.file as? PBXFileReference {
              fileReferences.insert(fileRef)
            }
          }
        }
      case let resourcesBuildPhase as PBXResourcesBuildPhase:
        if let files = resourcesBuildPhase.files {
          for buildFile in files {
            if let fileRef = buildFile.file as? PBXFileReference {
              fileReferences.insert(fileRef)
            }
          }
        }
      case let frameworksBuildPhase as PBXFrameworksBuildPhase:
        if let files = frameworksBuildPhase.files {
          for buildFile in files {
            if let fileRef = buildFile.file as? PBXFileReference {
              fileReferences.insert(fileRef)
            }
          }
        }
      case let copyFilesBuildPhase as PBXCopyFilesBuildPhase:
        if let files = copyFilesBuildPhase.files {
          for buildFile in files {
            if let fileRef = buildFile.file as? PBXFileReference {
              fileReferences.insert(fileRef)
            }
          }
        }
      default:
        continue
      }
    }

    // Sort and display files
    let sortedFiles = fileReferences.sorted {
      ($0.path ?? $0.name ?? "") < ($1.path ?? $1.name ?? "")
    }

    for fileRef in sortedFiles {
      print("  - \(fileRef.path ?? fileRef.name ?? "unknown")")
    }

    if fileReferences.isEmpty {
      print("  (no files)")
    } else {
      print("\nTotal: \(fileReferences.count) file(s)")
    }
  }
}
