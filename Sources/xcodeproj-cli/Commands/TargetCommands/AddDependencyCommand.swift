//
// AddDependencyCommand.swift
// xcodeproj-cli
//
// Command for adding a dependency between targets
//

import Foundation
@preconcurrency import XcodeProj

/// Command for adding a dependency relationship between targets

struct AddDependencyCommand: Command {
  static let commandName = "add-dependency"

  static let description = "Add a dependency relationship between targets"

  static let category: CommandCategory = .targetManagement

  static func execute(with arguments: ParsedArguments, utility: XcodeProjUtility) throws {
    // Validate required arguments
    try requirePositionalArguments(
      arguments,
      count: 1,
      usage: "add-dependency requires: <target> --depends-on <target>"
    )

    let target = arguments.positional[0]

    // Get required depends-on flag
    let dependsOn = try arguments.requireFlag(
      "--depends-on",
      error: "add-dependency requires --depends-on flag"
    )

    // Validate both targets exist
    try validateTargets([target, dependsOn], in: utility)

    // Execute the command
    try utility.addDependency(to: target, dependsOn: dependsOn)
  }

  static func printUsage() {
    print(
      """
      add-dependency <target> --depends-on <dependency-target>
        Add a dependency relationship between targets
        
        Arguments:
          <target>                Target that will depend on another target
          --depends-on <target>   Target that will be depended upon
        
        Examples:
          add-dependency MyApp --depends-on MyLibrary
          add-dependency MyAppTests --depends-on MyApp
        
        Notes:
          - Creates a target dependency relationship
          - Both targets must exist in the project
          - Dependency target will be built before the dependent target
      """)
  }
}

// MARK: - BaseCommand conformance
extension AddDependencyCommand {

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
