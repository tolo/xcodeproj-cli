//
// AddFilesCommand.swift
// xcodeproj-cli
//
// Command for adding multiple files to the project in batch
//

import Foundation
@preconcurrency import XcodeProj

/// Command for adding multiple files to specified groups and targets in batch

struct AddFilesCommand: Command {
  static let commandName = "add-files"

  static let description = "Add multiple files to specified groups and targets in batch"

  static let category: CommandCategory = .fileOperations

  static func execute(with arguments: ParsedArguments, utility: XcodeProjUtility) throws {
    guard !arguments.positional.isEmpty else {
      throw ProjectError.invalidArguments(
        "add-files requires file paths. See usage below.")
    }

    // Get required targets flag
    let targetsStr = try arguments.requireFlag(
      "--targets", "-t",
      error: "add-files requires --targets or -t flag"
    )

    let targets = BaseCommand.parseTargets(from: targetsStr)

    // Validate targets exist
    try BaseCommand.validateTargets(targets, in: utility)

    // Check if we have file:group pairs or files with shared group
    var files: [(String, String)] = []

    // Check if any arguments contain colons (file:group format)
    let hasColonFormat = arguments.positional.contains { $0.contains(":") }

    if hasColonFormat {
      // Parse file:group pairs format
      for arg in arguments.positional {
        let parts = arg.split(separator: ":")
        if parts.count == 2 {
          files.append((String(parts[0]), String(parts[1])))
        } else {
          throw ProjectError.invalidArguments(
            "Invalid file:group format: '\(arg)'. Use 'file:group' or provide --group flag for all files."
          )
        }
      }
    } else {
      // Multiple files with shared group format
      let group = try arguments.requireFlag(
        "--group", "-g",
        error: "add-files requires --group or -g flag when not using file:group format"
      )

      // Validate group exists
      try BaseCommand.validateGroup(group, in: utility)

      // Create file:group pairs for all files
      for filePath in arguments.positional {
        files.append((filePath, group))
      }
    }

    // Validate groups exist (for colon format)
    if hasColonFormat {
      for (_, group) in files {
        try BaseCommand.validateGroup(group, in: utility)
      }
    }

    // Execute the command
    try utility.addFiles(files, to: targets)
  }

  static func printUsage() {
    print(
      """
      add-files <files...> --group <group> --targets <target1,target2>
      add-files <file1:group1> [file2:group2] ... --targets <target1,target2>
        Add multiple files to specified groups and targets in batch
        
        Arguments:
          <files...>            List of files to add (when using --group flag)
          <fileN:groupN>        File path paired with destination group (colon-separated format)
          --group, -g <group>   Group to add all files to (required for first format)
          --targets, -t <list>  Comma-separated list of target names
        
        Examples:
          add-files File1.swift File2.swift --group Sources --targets MyApp,MyAppTests
          add-files Model.swift:Models View.swift:Views --targets MyApp,MyAppTests
          add-files Helper.swift Utils.swift -g Utils -t MyApp
        
        Notes:
          - All files are added to all specified targets
          - Groups must exist before adding files
          - Cannot mix colon format with --group flag
      """)
  }
}
