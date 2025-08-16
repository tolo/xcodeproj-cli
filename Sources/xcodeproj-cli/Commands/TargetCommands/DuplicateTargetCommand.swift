//
// DuplicateTargetCommand.swift
// xcodeproj-cli
//
// Command for duplicating an existing target with a new name
//

import Foundation
@preconcurrency import XcodeProj

/// Command for duplicating an existing target with optional bundle ID override

struct DuplicateTargetCommand: Command {
  static let commandName = "duplicate-target"

  static let description = "Duplicate an existing target with a new name"

  static let category: CommandCategory = .targetManagement

  static func execute(with arguments: ParsedArguments, utility: XcodeProjUtility) throws {
    // Validate required arguments
    try requirePositionalArguments(
      arguments,
      count: 2,
      usage: "duplicate-target requires: <source-target> <new-name> [--bundle-id <bundle-id>]"
    )

    let sourceTarget = arguments.positional[0]
    let newName = arguments.positional[1]

    // Get optional bundle ID flag
    let bundleId = arguments.getFlag("--bundle-id", "-b")

    // Validate source target exists
    try validateTargets([sourceTarget], in: utility)

    // Execute the command
    try utility.duplicateTarget(source: sourceTarget, newName: newName, newBundleId: bundleId)
  }

  static func printUsage() {
    print(
      """
      duplicate-target <source-target> <new-name> [--bundle-id <bundle-id>]
        Duplicate an existing target with a new name
        
        Arguments:
          <source-target>       Name of the target to duplicate
          <new-name>           Name for the new target
          --bundle-id, -b <id> Optional new bundle identifier (defaults to source target's bundle ID)
        
        Examples:
          duplicate-target MyApp MyAppClone
          duplicate-target MyApp MyAppPro --bundle-id com.company.myapp.pro
          duplicate-target MyApp MyAppDebug -b com.company.myapp.debug
        
        Notes:
          - All build settings and dependencies are copied
          - Files are shared between original and duplicated targets
          - Bundle ID is optional; if not provided, duplicates source bundle ID
      """)
  }
}

// MARK: - BaseCommand conformance
extension DuplicateTargetCommand {

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
