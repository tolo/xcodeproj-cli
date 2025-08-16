//
// RemoveTargetFileCommand.swift
// xcodeproj-cli
//
// Command for removing a file from a target's compile sources
//

import Foundation
@preconcurrency import XcodeProj

/// Command for removing a file from a target's compile sources or resources without removing it from the project

struct RemoveTargetFileCommand: Command {
  static let commandName = "remove-target-file"

  static let description =
    "Remove a file from a target's compile sources or resources without removing it from the project"

  static let category: CommandCategory = .targetManagement

  static func execute(with arguments: ParsedArguments, utility: XcodeProjUtility) throws {
    // Validate required arguments
    try BaseCommand.requirePositionalArguments(
      arguments,
      count: 1,
      usage: "remove-target-file requires: <file-path> --targets <target1,target2>"
    )

    let filePath = try PathUtils.validatePath(arguments.positional[0])

    // Get targets using the new helper that accepts both --target and --targets
    guard let targets = try BaseCommand.getTargets(from: arguments, requireFlag: true) else {
      throw ProjectError.invalidArguments("remove-target-file requires --targets or --target flag")
    }

    // Validate targets exist
    try BaseCommand.validateTargets(targets, in: utility)

    // Execute the command for each target
    for targetName in targets {
      try utility.removeFileFromTarget(path: filePath, targetName: targetName)
    }
  }

  nonisolated static func printUsage() {
    print(
      """
      remove-target-file <file-path> (--targets <target1,target2> | --target <target>)
        Remove a file from target build phases without removing it from the project
        
        Arguments:
          <file-path>                   Path to the file in the project
                                        Can be: filename only (Model.swift),
                                        partial path (Sources/Model.swift),
                                        or full project path
          --targets, --target, -t <list>  Target names (comma-separated for multiple)
                                        --targets: accepts multiple comma-separated targets
                                        --target: accepts single or comma-separated targets
                                        -t: short form for either flag
        
        Examples:
          remove-target-file Sources/Model.swift --targets MyAppTests
          remove-target-file Helper.swift --target MyApp
          remove-target-file Utils.swift --targets MyApp,MyWidget
          remove-target-file Config.swift -t MyFramework
      """)
  }
}
