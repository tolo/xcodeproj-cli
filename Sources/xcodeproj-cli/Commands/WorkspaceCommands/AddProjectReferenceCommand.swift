//
// AddProjectReferenceCommand.swift
// xcodeproj-cli
//
// Command for adding references to external projects
//

import Foundation
@preconcurrency import PathKit
@preconcurrency import XcodeProj

struct AddProjectReferenceCommand: Command {
  static let commandName = "add-project-reference"
  static let description = "Add a reference to an external project"

  static let category: CommandCategory = .crossProject

  let projectPath: String
  let groupPath: String?
  let verbose: Bool

  init(arguments: ParsedArguments) throws {
    guard let path = arguments.positional.first else {
      throw ProjectError.invalidArguments("Project path is required")
    }

    self.projectPath = path
    self.groupPath = arguments.getFlag("group")
    self.verbose = arguments.boolFlags.contains("verbose")
  }

  @MainActor
  func execute(with xcodeproj: XcodeProj, projectPath: Path) throws {
    let crossProjectManager = CrossProjectManager(xcodeproj: xcodeproj, projectPath: projectPath)

    // Add project reference
    let fileRef = try crossProjectManager.addProjectReference(
      externalProjectPath: self.projectPath,
      groupPath: groupPath
    )

    if verbose {
      print("  Referenced project: \(self.projectPath)")
      print("  File reference ID: \(fileRef.uuid)")
      if let group = groupPath {
        print("  Added to group: \(group)")
      } else {
        print("  Added to root group")
      }
    }
  }

  static func printUsage() {
    print(
      """
      Usage: add-project-reference <project-path> [options]

      Arguments:
        project-path      Path to the external project file

      Options:
        --group <path>    Group path where to add the reference
        --verbose         Show detailed output

      Examples:
        add-project-reference ../Framework/Framework.xcodeproj
        add-project-reference ../Shared/Shared.xcodeproj --group Dependencies
        add-project-reference /path/to/ExternalLib.xcodeproj --group External/Libraries
      """)
  }

  @MainActor
  static func execute(with arguments: ParsedArguments, utility: XcodeProjUtility) throws {
    let cmd = try AddProjectReferenceCommand(arguments: arguments)
    try cmd.execute(with: utility.xcodeproj, projectPath: utility.projectPath)
  }
}
