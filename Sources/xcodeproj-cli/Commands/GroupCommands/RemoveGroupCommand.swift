//
// RemoveGroupCommand.swift
// xcodeproj-cli
//
// Command for removing groups from the project
//

import Foundation
@preconcurrency import XcodeProj

/// Command for removing groups and their contents from the project

struct RemoveGroupCommand: Command {
  static let commandName = "remove-group"

  static let description = "Remove a group and its contents from the project"

  static let category: CommandCategory = .groupOperations

  static func execute(with arguments: ParsedArguments, utility: XcodeProjUtility) throws {
    // Validate required arguments
    try requirePositionalArguments(
      arguments,
      count: 1,
      usage: "remove-group requires: <group-path>"
    )

    let groupPath = arguments.positional[0]

    // Execute the command
    try utility.removeGroup(groupPath)

    // Save changes
    try utility.save()
  }

  static func printUsage() {
    print(
      """
      remove-group <group-path>
        Remove a group and its contents from the project
        
        Arguments:
          <group-path>  Path to the group to remove
        
        Examples:
          remove-group Sources/Models
          remove-group Utils
        
        Warning: This removes the group and all its contents from the project
      """)
  }
}

// MARK: - BaseCommand conformance
extension RemoveGroupCommand {

  private static func requirePositionalArguments(
    _ arguments: ParsedArguments, count: Int, usage: String
  ) throws {
    try BaseCommand.requirePositionalArguments(arguments, count: count, usage: usage)
  }
}
