//
// AddCrossProjectDependencyCommand.swift
// xcodeproj-cli
//
// Command for adding cross-project dependencies
//

import Foundation
@preconcurrency import PathKit
@preconcurrency import XcodeProj

struct AddCrossProjectDependencyCommand: Command {
  static let commandName = "add-cross-project-dependency"
  static let description = "Add a dependency on a target in another project"

  static let category: CommandCategory = .crossProject

  let targetName: String
  let externalProject: String
  let externalTarget: String
  let externalTargetGUID: String?
  let verbose: Bool

  init(arguments: ParsedArguments) throws {
    guard arguments.positional.count >= 3 else {
      throw ProjectError.invalidArguments(
        "Target name, external project, and external target are required")
    }

    self.targetName = arguments.positional[0]
    self.externalProject = arguments.positional[1]
    self.externalTarget = arguments.positional[2]
    self.externalTargetGUID = arguments.getFlag("target-id")
    self.verbose = arguments.boolFlags.contains("verbose")
  }

  @MainActor
  func execute(with xcodeproj: XcodeProj, projectPath: Path) throws {
    let crossProjectManager = CrossProjectManager(xcodeproj: xcodeproj, projectPath: projectPath)

    // Add cross-project dependency
    try crossProjectManager.addCrossProjectDependency(
      targetName: targetName,
      externalProjectPath: externalProject,
      externalTargetName: externalTarget,
      externalTargetGUID: externalTargetGUID
    )

    if verbose {
      print("  Target: \(targetName)")
      print("  External project: \(externalProject)")
      print("  External target: \(externalTarget)")
      if let guid = externalTargetGUID {
        print("  External target GUID: \(guid)")
      }
    }
  }

  static func printUsage() {
    print(
      """
      Usage: add-cross-project-dependency <target> <external-project> <external-target> [options]

      Arguments:
        target            Name of the target to add dependency to
        external-project  Path to the external project
        external-target   Name of the target in the external project

      Options:
        --target-id <id>  Specific GUID of the external target (optional)
        --verbose         Show detailed output

      Examples:
        add-cross-project-dependency MyApp ../Framework/Framework.xcodeproj MyFramework
        add-cross-project-dependency MyAppTests ../Shared/Shared.xcodeproj SharedUtils
        add-cross-project-dependency MyTarget External.xcodeproj ExternalLib --target-id ABC123
      """)
  }

  @MainActor
  static func execute(with arguments: ParsedArguments, utility: XcodeProjUtility) throws {
    let cmd = try AddCrossProjectDependencyCommand(arguments: arguments)
    try cmd.execute(with: utility.xcodeproj, projectPath: utility.projectPath)
  }
}
