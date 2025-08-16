//
// RemoveFileCommand.swift
// xcodeproj-cli
//
// Command for removing a file from the project
//

import Foundation
@preconcurrency import XcodeProj

/// Command for removing a file from the project

struct RemoveFileCommand: Command {
  static let commandName = "remove-file"

  static let description = "Remove a file from the project"

  static let category: CommandCategory = .fileOperations

  static func execute(with arguments: ParsedArguments, utility: XcodeProjUtility) throws {
    // Validate required arguments
    try requirePositionalArguments(
      arguments,
      count: 1,
      usage: "remove-file requires: <file-path>"
    )

    let filePath = arguments.positional[0]

    // Execute the command
    try utility.removeFile(filePath)
  }

  static func printUsage() {
    print(
      """
      remove-file <file-path>
        Remove a file from the project
        
        Arguments:
          <file-path>  Path or name of the file to remove from the project
        
        Examples:
          remove-file Sources/OldFile.swift
          remove-file Helper.swift
          
        Note: This only removes the file reference from the project,
              it does not delete the file from the filesystem.
      """)
  }
}

// MARK: - BaseCommand conformance
extension RemoveFileCommand {

  private static func requirePositionalArguments(
    _ arguments: ParsedArguments, count: Int, usage: String
  ) throws {
    try BaseCommand.requirePositionalArguments(arguments, count: count, usage: usage)
  }
}
