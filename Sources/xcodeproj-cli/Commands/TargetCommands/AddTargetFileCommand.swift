//
// AddTargetFileCommand.swift
// xcodeproj-cli
//
// Command for adding an existing file to a target's compile sources
//

import Foundation
@preconcurrency import XcodeProj

/// Command for adding an existing file to a target's compile sources or resources

struct AddTargetFileCommand: Command {
  static let commandName = "add-target-file"

  static let description = "Add an existing file to a target's compile sources or resources"

  static let category: CommandCategory = .targetManagement

  static func execute(with arguments: ParsedArguments, utility: XcodeProjUtility) throws {
    // Validate required arguments
    try BaseCommand.requirePositionalArguments(
      arguments,
      count: 1,
      usage: "add-target-file requires: <file-path> --targets <target1,target2>"
    )

    let filePath = try PathUtils.validatePath(arguments.positional[0])

    // Get targets using the new helper that accepts both --target and --targets
    guard let targets = try BaseCommand.getTargets(from: arguments, requireFlag: true) else {
      throw ProjectError.invalidArguments("add-target-file requires --targets or --target flag")
    }

    // Validate targets exist
    try BaseCommand.validateTargets(targets, in: utility)

    // Execute the command for each target
    for targetName in targets {
      try utility.addFileToTarget(path: filePath, targetName: targetName)
    }
  }

  nonisolated static func printUsage() {
    print(
      """
      add-target-file <file-path> (--targets <target1,target2> | --target <target>)
        Add an existing file to target build phases
        
        Arguments:
          <file-path>                   Path to the file (must already exist in project)
                                        Can be: filename only (Model.swift),
                                        partial path (Sources/Model.swift),
                                        or full project path
          --targets, --target, -t <list>  Target names (comma-separated for multiple)
                                        --targets: accepts multiple comma-separated targets
                                        --target: accepts single or comma-separated targets
                                        -t: short form for either flag
        
        Examples:
          add-target-file Sources/Model.swift --targets MyApp
          add-target-file Helper.swift --target MyAppTests
          add-target-file Utils.swift --targets MyApp,MyWidget
          add-target-file Config.swift -t MyFramework
      """)
  }
}
