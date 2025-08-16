//
// ListFilesCommand.swift
// xcodeproj-cli
//
// Command for listing files in the project or a specific group
//

import Foundation
@preconcurrency import XcodeProj

/// Command for listing files in the project or a specific group

struct ListFilesCommand: Command {
  static let commandName = "list-files"

  static let description = "List files in the project or a specific group"

  static let category: CommandCategory = .inspection

  static let isReadOnly = true

  static func execute(with arguments: ParsedArguments, utility: XcodeProjUtility) throws {
    let groupName = arguments.positional.first
    let targetName = arguments.getFlag("--target", "-t")

    // If target filter is specified, show files in that target
    if let targetName = targetName {
      try listFilesInTarget(targetName, utility: utility)
      return
    }

    if let name = groupName,
      let group = XcodeProjectHelpers.findGroup(named: name, in: utility.pbxproj.groups)
    {
      print("📁 Files in group '\(name)':")
      ListFilesCommand.listFilesInGroup(group)
    } else if let name = groupName {
      throw ProjectError.groupNotFound(name)
    } else {
      print("📁 All files in project:")
      if let rootGroup = utility.pbxproj.rootObject?.mainGroup {
        ListFilesCommand.listFilesInGroup(rootGroup)
      } else {
        print("❌ No project structure found")
      }
    }
  }

  static func printUsage() {
    print(
      """
      list-files [group-name] [--target <target-name>]
        List files in the project, a specific group, or a specific target
        
        Arguments:
          [group-name]          Optional: specific group to list files from
          --target, -t <name>   Optional: list only files in specified target
        
        Examples:
          list-files                    # List all files in project
          list-files Sources            # List files in Sources group
          list-files --target MyApp     # List files in MyApp target
          list-files -t MyAppTests      # List files in MyAppTests target
      """)
  }
}

// MARK: - Helper methods
extension ListFilesCommand {
  static func listFilesInGroup(_ group: PBXGroup, indent: String = "") {
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
  static func listFilesInTarget(_ targetName: String, utility: XcodeProjUtility) throws {
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
