//
// UpdatePathsCommand.swift
// xcodeproj-cli
//
// Command for updating file paths with a prefix replacement
//

import Foundation
@preconcurrency import XcodeProj

/// Command for updating file paths using prefix replacement

struct UpdatePathsCommand: Command {
  static let commandName = "update-paths"

  static let description = "Update file paths with prefix replacement"

  static let category: CommandCategory = .pathOperations

  static func execute(with arguments: ParsedArguments, utility: XcodeProjUtility) throws {
    // Validate required arguments
    try requirePositionalArguments(
      arguments,
      count: 2,
      usage: "update-paths requires: <old-prefix> <new-prefix>"
    )

    let oldPrefix = arguments.positional[0]
    let newPrefix = arguments.positional[1]

    // Execute the command
    utility.updatePathsWithPrefix(from: oldPrefix, to: newPrefix)
  }

  static func printUsage() {
    print(
      """
      update-paths <old-prefix> <new-prefix>
        Update file paths with prefix replacement
        
        Arguments:
          <old-prefix>          Old path prefix to replace
          <new-prefix>          New path prefix to use
        
        Examples:
          update-paths "Sources/Old" "Sources/New"
          update-paths "/old/path" "/new/path"
        
        Notes:
          - Updates all file paths in project that start with old-prefix
          - Useful for reorganizing project structure
          - Project is automatically saved after updates
      """)
  }
}

// MARK: - BaseCommand conformance
extension UpdatePathsCommand {

  private static func requirePositionalArguments(
    _ arguments: ParsedArguments, count: Int, usage: String
  ) throws {
    try BaseCommand.requirePositionalArguments(arguments, count: count, usage: usage)
  }
}
