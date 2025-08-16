//
// AddFrameworkCommand.swift
// xcodeproj-cli
//
// Command for adding a framework to a target
//

import Foundation
@preconcurrency import XcodeProj

/// Command for adding a framework to a target with optional embedding

struct AddFrameworkCommand: Command {
  static let commandName = "add-framework"

  static let description = "Add a framework to a target"

  static let category: CommandCategory = .frameworks

  static func execute(with arguments: ParsedArguments, utility: XcodeProjUtility) throws {
    // Validate required arguments
    try requirePositionalArguments(
      arguments,
      count: 1,
      usage: "add-framework requires: <framework-name> --target <target> [--embed]"
    )

    let frameworkName = arguments.positional[0]

    // Get required target flag (support both --target and --targets for consistency)
    let targetName: String
    if let target = arguments.getFlag("--target", "-t") {
      targetName = target
    } else if let targets = arguments.getFlag("--targets") {
      targetName = targets
    } else {
      throw ProjectError.invalidArguments("add-framework requires --target/-t or --targets flag")
    }

    // Get optional embed flag
    let embed = arguments.hasFlag("--embed", "-e")

    // Validate target exists
    try validateTargets([targetName], in: utility)

    // Execute the command
    try utility.addFramework(name: frameworkName, to: targetName, embed: embed)
  }

  static func printUsage() {
    print(
      """
      add-framework <framework-name> --target <target> [--embed]
      add-framework <framework-name> --targets <target> [--embed]
        Add a framework to a target
        
        Arguments:
          <framework-name>       Name of the framework to add
          --target, -t <target>  Target to add the framework to
          --targets <target>     Target to add the framework to (alternative)
          --embed, -e            Embed the framework in the app bundle
        
        Examples:
          add-framework UIKit --target MyApp
          add-framework UIKit --targets MyApp
          add-framework MyLibrary --target MyApp --embed
          add-framework CoreData -t MyApp
        
        Notes:
          - Framework is added to the target's Link Binary With Libraries phase
          - Use --embed for dynamic frameworks that need to be bundled
          - Target must exist before adding framework
      """)
  }
}

// MARK: - BaseCommand conformance
extension AddFrameworkCommand {

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
