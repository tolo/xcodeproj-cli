//
// AddFolderCommand.swift
// xcodeproj-cli
//
// Command for adding files from a filesystem folder to the project
//

import Foundation
import XcodeProj

/// Command for adding files from a filesystem folder to project group

struct AddFolderCommand: Command {
  static let commandName = "add-folder"

  static let description = "Add files from filesystem folder to project group"

  static func execute(with arguments: ParsedArguments, utility: XcodeProjUtility) throws {
    // Validate required arguments
    try requirePositionalArguments(
      arguments,
      count: 1,
      usage:
        "add-folder requires: <folder-path> --group <group> --targets <target1,target2> [--recursive]"
    )

    let folderPath = arguments.positional[0]

    // Get required flags
    let group = try arguments.requireFlag(
      "--group", "-g",
      error: "add-folder requires --group or -g flag"
    )

    let targetsStr = try arguments.requireFlag(
      "--targets", "-t",
      error: "add-folder requires --targets or -t flag"
    )

    let targets = parseTargets(from: targetsStr)
    let recursive = arguments.hasFlag("--recursive", "-r")

    // Validate inputs
    try validateGroup(group, in: utility)
    try validateTargets(targets, in: utility)

    // Execute the command
    try utility.addFolder(
      folderPath: folderPath,
      to: group,
      targets: targets,
      recursive: recursive
    )
  }

  static func printUsage() {
    print(
      """
      add-folder <folder-path> --group <group> --targets <target1,target2> [--recursive]
        Add files from filesystem folder to project group
        
        Arguments:
          <folder-path>         Path to the folder containing files to add
          --group, -g <group>   Group to add the files to
          --targets, -t <list>  Comma-separated list of target names
          --recursive, -r       Include files from subdirectories (optional)
        
        Examples:
          add-folder Sources/Utils --group Utils --targets MyApp --recursive
          add-folder Resources -g Resources -t MyApp,MyAppTests
      """)
  }
}

// MARK: - BaseCommand conformance
extension AddFolderCommand {
  private static func requirePositionalArguments(
    _ arguments: ParsedArguments, count: Int, usage: String
  ) throws {
    try BaseCommand.requirePositionalArguments(arguments, count: count, usage: usage)
  }

  private static func parseTargets(from targetsString: String) -> [String] {
    return BaseCommand.parseTargets(from: targetsString)
  }

  private static func validateTargets(_ targetNames: [String], in utility: XcodeProjUtility) throws
  {
    try BaseCommand.validateTargets(targetNames, in: utility)
  }

  private static func validateGroup(_ groupPath: String, in utility: XcodeProjUtility) throws {
    try BaseCommand.validateGroup(groupPath, in: utility)
  }
}
