//
// GetBuildSettingsCommand.swift
// xcodeproj-cli
//

import ArgumentParser
import Foundation

/// ArgumentParser command for getting build settings from a target (read-only)
struct GetBuildSettingsCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "get-build-settings",
    abstract: "Get build settings from a target",
    discussion: """
      Retrieve build settings for a specific target, optionally filtered by configuration.

      Examples:
        xcodeproj-cli get-build-settings MyApp
        xcodeproj-cli get-build-settings MyApp --config Debug
        xcodeproj-cli get-build-settings --target MyApp --configuration Release
      """
  )

  @OptionGroup var global: GlobalOptions

  @Argument(
    help: "Target name (can also use --target flag)"
  )
  var targetName: String?

  @Option(
    name: [.customLong("target"), .customShort("t")],
    help: "Target name (alternative to positional argument)"
  )
  var targetFlag: String?

  @Option(
    name: [.customLong("config"), .customShort("c")],
    help: "Optional: specific configuration name"
  )
  var config: String?

  @Option(
    name: [.customLong("configuration")],
    help: "Optional: specific configuration name (alternative to --config)"
  )
  var configuration: String?

  @MainActor
  func run() async throws {
    // Determine target name from positional argument or flag
    guard let target = targetName ?? targetFlag else {
      throw ProjectError.invalidArguments(
        "get-build-settings requires a target name (positional argument or --target flag)")
    }

    // Determine configuration (prefer --config over --configuration)
    let selectedConfig = config ?? configuration

    // Create project services (read-only, no save needed)
    let services = try ProjectServiceFactory.create(from: global, readOnly: true)

    // Validate target exists
    let projectTargets = Set(services.utility.pbxproj.nativeTargets.map { $0.name })
    guard projectTargets.contains(target) else {
      throw ProjectError.targetNotFound(target)
    }

    // Execute the command
    let settings = services.utility.getBuildSettings(for: target, configuration: selectedConfig)

    print("🔧 Build settings for \(target):")
    if settings.isEmpty {
      print("  No settings found")
    } else {
      // Sort configuration names for deterministic output
      let sortedConfigs = settings.keys.sorted()
      for configName in sortedConfigs {
        guard let configSettings = settings[configName] else { continue }
        print("  \(configName):")
        let sortedKeys = configSettings.keys.sorted()
        for key in sortedKeys {
          let value = configSettings[key]
          print("    \(key) = \(value ?? "nil")")
        }
      }
    }
  }
}
