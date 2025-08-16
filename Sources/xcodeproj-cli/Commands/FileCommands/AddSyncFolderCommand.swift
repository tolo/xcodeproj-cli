//
// AddSyncFolderCommand.swift
// xcodeproj-cli
//
// Command for adding a synchronized folder to the project
//

import Foundation
@preconcurrency import XcodeProj

/// Command for adding a synchronized folder that maintains sync with filesystem

struct AddSyncFolderCommand: Command {
  static let commandName = "add-sync-folder"

  static let description = "Add a synchronized folder that maintains sync with filesystem"

  static let category: CommandCategory = .fileOperations

  static func execute(with arguments: ParsedArguments, utility: XcodeProjUtility) throws {
    // Validate required arguments
    try BaseCommand.requirePositionalArguments(
      arguments,
      count: 1,
      usage: "add-sync-folder requires: <folder-path> --group <group> --targets <target1,target2>"
    )

    let folderPath = arguments.positional[0]

    // Get required flags
    let group = try arguments.requireFlag(
      "--group", "-g",
      error: "add-sync-folder requires --group or -g flag"
    )

    let targetsStr = try arguments.requireFlag(
      "--targets", "-t",
      error: "add-sync-folder requires --targets or -t flag"
    )

    let targets = BaseCommand.parseTargets(from: targetsStr)

    // Validate inputs
    try BaseCommand.validateGroup(group, in: utility)
    try BaseCommand.validateTargets(targets, in: utility)

    // Execute the command
    try utility.addSynchronizedFolder(folderPath: folderPath, to: group, targets: targets)
  }

  static func printUsage() {
    print(
      """
      add-sync-folder <folder-path> --group <group> --targets <target1,target2>
        Add a synchronized folder that maintains sync with filesystem
        
        Arguments:
          <folder-path>         Path to the folder to add
          --group, -g <group>   Group to add the folder to
          --targets, -t <list>  Comma-separated list of target names
        
        Examples:
          add-sync-folder Sources/Models --group Models --targets MyApp,MyAppTests
          add-sync-folder Resources -g Assets -t MyApp
        
        Notes:
          - Folder will be synchronized with filesystem changes
          - All files in folder are added to specified targets
          - Group must exist before adding folder
      """)
  }
}
