//
// MoveFileCommand.swift
// xcodeproj-cli
//
// Command for moving/renaming a file in the project
//

import Foundation
@preconcurrency import XcodeProj

/// Command for moving or renaming a file in the project

struct MoveFileCommand: Command {
  static let commandName = "move-file"

  static let description = "Move or rename a file in the project"

  static let category: CommandCategory = .fileOperations

  static func execute(with arguments: ParsedArguments, utility: XcodeProjUtility) throws {
    // Validate required arguments
    try requirePositionalArguments(
      arguments,
      count: 1,
      usage: "move-file requires: <file-path> [--to-group <group>] [<new-path>]"
    )

    let filePath = arguments.positional[0]

    // Check if moving to a different group
    if let targetGroup = arguments.flags["--to-group"] {
      // Move file to a different group
      try utility.moveFileToGroup(filePath: filePath, targetGroup: targetGroup)
    } else if arguments.positional.count >= 2 {
      // Traditional move/rename with new path
      let newPath = arguments.positional[1]
      try utility.moveFile(from: filePath, to: newPath)
    } else {
      throw ProjectError.invalidArguments(
        "move-file requires either --to-group <group> or <new-path>")
    }
  }

  static func printUsage() {
    print(
      """
      move-file <file-path> [<new-path>] [--to-group <group>]
        Move or rename a file in the project
        
        Arguments:
          <file-path>           Current path or name of the file
          <new-path>            New path or name for the file (for renaming)
          --to-group <group>    Move file to a different group
        
        Examples:
          move-file OldName.swift NewName.swift
          move-file Helper.swift --to-group Utils
          
        Note: This updates the file reference in the project.
              If the file needs to be moved on disk, you should do that separately.
      """)
  }
}

// MARK: - BaseCommand conformance
extension MoveFileCommand {

  private static func requirePositionalArguments(
    _ arguments: ParsedArguments, count: Int, usage: String
  ) throws {
    try BaseCommand.requirePositionalArguments(arguments, count: count, usage: usage)
  }
}
