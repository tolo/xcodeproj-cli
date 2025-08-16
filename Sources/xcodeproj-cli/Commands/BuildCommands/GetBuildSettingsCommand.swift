//
// GetBuildSettingsCommand.swift
// xcodeproj-cli
//
// Command for getting build settings from targets
//

import Foundation
@preconcurrency import XcodeProj

/// Command for getting build settings from a target

struct GetBuildSettingsCommand: Command {
  static let commandName = "get-build-settings"

  static let description = "Get build settings from a target"

  static let category: CommandCategory = .buildConfiguration

  static let isReadOnly = true
  static func execute(with arguments: ParsedArguments, utility: XcodeProjUtility) throws {
    let targetName: String
    let configuration = arguments.getFlag("--config", "-c") ?? arguments.getFlag("--configuration")

    // Check if target is provided as --targets flag or positional argument
    if let targetsFlag = arguments.getFlag("--targets") {
      targetName = targetsFlag
    } else if arguments.positional.count >= 1 {
      targetName = arguments.positional[0]
    } else {
      throw ProjectError.invalidArguments(
        "get-build-settings requires: <target> [--config <configuration>]")
    }

    // Validate target exists
    try validateTargets([targetName], in: utility)

    // Execute the command
    let settings = utility.getBuildSettings(for: targetName, configuration: configuration)

    print("🔧 Build settings for \(targetName):")
    if settings.isEmpty {
      print("  No settings found")
    } else {
      for (configName, configSettings) in settings {
        print("  \(configName):")
        let sortedKeys = configSettings.keys.sorted()
        for key in sortedKeys {
          let value = configSettings[key]
          print("    \(key) = \(value ?? "nil")")
        }
      }
    }
  }

  static func printUsage() {
    print(
      """
      get-build-settings <target> [--config <configuration>]
      get-build-settings --targets <target> [--config <configuration>]
        Get build settings from a target
        
        Arguments:
          <target>                      Target name (positional)
          --targets <target>            Target name (flag)
          --config, -c <config>         Optional: specific configuration name
          --configuration <config>      Optional: specific configuration name
        
        Examples:
          get-build-settings MyApp
          get-build-settings MyApp --config Debug
          get-build-settings --targets MyApp --configuration Release
      """)
  }
}

// MARK: - BaseCommand conformance
extension GetBuildSettingsCommand {

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
