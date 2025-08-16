//
// RemoveTargetCommand.swift
// xcodeproj-cli
//
// Command for removing a target from the project
//

import Foundation
@preconcurrency import XcodeProj

/// Command for removing a target from the project

struct RemoveTargetCommand: Command {
  static let commandName = "remove-target"

  static let description = "Remove a target from the project"

  static let category: CommandCategory = .targetManagement

  static func execute(with arguments: ParsedArguments, utility: XcodeProjUtility) throws {
    // Validate required arguments
    try requirePositionalArguments(
      arguments,
      count: 1,
      usage: "remove-target requires: <target-name>"
    )

    let targetName = arguments.positional[0]

    // Validate that the target exists
    try validateTargets([targetName], in: utility)

    // Execute the command
    try utility.removeTarget(name: targetName)
  }

  static func printUsage() {
    print(
      """
      remove-target <target-name>
        Remove a target from the project
        
        Arguments:
          <target-name>  Name of the target to remove
        
        Examples:
          remove-target MyAppTests
          remove-target OldFramework
          
        Warning: This will permanently remove the target and all its
                 build settings, dependencies, and file references.
      """)
  }
}

// MARK: - BaseCommand conformance
extension RemoveTargetCommand {

  private static func requirePositionalArguments(
    _ arguments: ParsedArguments, count: Int, usage: String
  ) throws {
    try BaseCommand.requirePositionalArguments(arguments, count: count, usage: usage)
  }

  @MainActor
  private static func validateTargets(_ targetNames: [String], in utility: XcodeProjUtility) throws
  {
    try BaseCommand.validateTargets(targetNames, in: utility)
  }
}
