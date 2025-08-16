//
// ListBuildSettingsCommand.swift
// xcodeproj-cli
//
// Command for listing build settings for project or target
//

import Foundation
@preconcurrency import XcodeProj

/// Command for listing build settings with various filtering options

struct ListBuildSettingsCommand: Command {
  static let commandName = "list-build-settings"

  static let description = "List build settings for project or target"

  static let category: CommandCategory = .buildConfiguration

  static let isReadOnly = true
  static func execute(with arguments: ParsedArguments, utility: XcodeProjUtility) throws {
    // Get optional flags
    let targetName = arguments.getFlag("--target", "-t")
    let config = arguments.getFlag("--config", "-c")
    let showInherited = arguments.hasFlag("--show-inherited", "-i")
    let outputJSON = arguments.hasFlag("--json", "-j")
    let showAll = arguments.hasFlag("--all", "-a")

    // Validate target if specified
    if let target = targetName {
      try validateTargets([target], in: utility)
    }

    // Execute the command
    utility.listBuildSettings(
      targetName: targetName,
      configuration: config,
      showInherited: showInherited,
      outputJSON: outputJSON,
      showAll: showAll
    )
  }

  static func printUsage() {
    print(
      """
      list-build-settings [--target <target>] [--config <config>] [--show-inherited] [--json] [--all]
        List build settings for project or target
        
        Arguments:
          --target, -t <target>     Target name (optional, shows project settings if omitted)
          --config, -c <config>     Configuration name (optional, shows all if omitted)
          --show-inherited, -i      Show inherited settings from project
          --json, -j                Output in JSON format
          --all, -a                 Show all settings including default values
        
        Examples:
          list-build-settings
          list-build-settings --target MyApp
          list-build-settings --target MyApp --config Debug
          list-build-settings -t MyApp -c Release --json
          list-build-settings --all --show-inherited
        
        Notes:
          - Without --target, shows project-level settings
          - Without --config, shows all configurations
          - JSON output is useful for automated processing
      """)
  }
}

// MARK: - BaseCommand conformance
extension ListBuildSettingsCommand {

  @MainActor
  private static func validateTargets(_ targetNames: [String], in utility: XcodeProjUtility) throws
  {
    try BaseCommand.validateTargets(targetNames, in: utility)
  }
}
