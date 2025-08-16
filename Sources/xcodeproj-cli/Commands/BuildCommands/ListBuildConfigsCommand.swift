//
// ListBuildConfigsCommand.swift
// xcodeproj-cli
//
// Command for listing build configurations
//

import Foundation
@preconcurrency import XcodeProj

/// Command for listing build configurations for a target or the project

struct ListBuildConfigsCommand: Command {
  static let commandName = "list-build-configs"

  static let description = "List build configurations for a target or the project"

  static let category: CommandCategory = .buildConfiguration

  static let isReadOnly = true
  static func execute(with arguments: ParsedArguments, utility: XcodeProjUtility) throws {
    let targetName = arguments.getFlag("--target", "-t")

    // If target is specified, validate it exists
    if let target = targetName {
      try validateTargets([target], in: utility)
    }

    // Execute the command
    utility.listBuildConfigurations(for: targetName)
  }

  static func printUsage() {
    print(
      """
      list-build-configs [--target <target>]
        List build configurations for a target or the project
        
        Arguments:
          --target, -t <target>     Optional: target name (lists project configs if omitted)
        
        Examples:
          list-build-configs                    # List project configurations
          list-build-configs --target MyApp     # List configurations for MyApp target
      """)
  }
}

// MARK: - BaseCommand conformance
extension ListBuildConfigsCommand {

  @MainActor
  private static func validateTargets(_ targetNames: [String], in utility: XcodeProjUtility) throws
  {
    try BaseCommand.validateTargets(targetNames, in: utility)
  }
}
