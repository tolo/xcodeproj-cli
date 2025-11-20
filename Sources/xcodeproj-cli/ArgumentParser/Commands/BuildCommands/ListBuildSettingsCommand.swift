//
// ListBuildSettingsCommand.swift
// xcodeproj-cli
//

import ArgumentParser
import Foundation

/// ArgumentParser command for listing build settings (read-only)
struct ListBuildSettingsCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "list-build-settings",
    abstract: "List build settings for project or target",
    discussion: """
      List build settings with various filtering options. Without --target, shows project-level settings.

      Examples:
        xcodeproj-cli list-build-settings
        xcodeproj-cli list-build-settings --target MyApp
        xcodeproj-cli list-build-settings --target MyApp --config Debug
        xcodeproj-cli list-build-settings -t MyApp -c Release --json
        xcodeproj-cli list-build-settings --all --show-inherited

      Notes:
        - Without --target, shows project-level settings
        - Without --config, shows all configurations
        - JSON output is useful for automated processing
      """
  )

  @OptionGroup var global: GlobalOptions

  @Option(
    name: [.customLong("target"), .customShort("t")],
    help: "Target name (optional, shows project settings if omitted)"
  )
  var targetName: String?

  @Option(
    name: [.customLong("config"), .customShort("c")],
    help: "Configuration name (optional, shows all if omitted)"
  )
  var config: String?

  @Flag(
    name: [.customLong("show-inherited"), .customShort("i")],
    help: "Show inherited settings from project"
  )
  var showInherited = false

  @Flag(
    name: [.customLong("json"), .customShort("j")],
    help: "Output in JSON format"
  )
  var outputJSON = false

  @Flag(
    name: [.customLong("all"), .customShort("a")],
    help: "Show all settings including default values"
  )
  var showAll = false

  @MainActor
  func run() async throws {
    // Create project services (read-only, no save needed)
    let services = try ProjectServiceFactory.create(from: global, readOnly: true)

    // Validate target if specified
    if let target = targetName {
      let projectTargets = Set(services.utility.pbxproj.nativeTargets.map { $0.name })
      guard projectTargets.contains(target) else {
        throw ProjectError.targetNotFound(target)
      }
    }

    // Execute the command
    services.utility.listBuildSettings(
      targetName: targetName,
      configuration: config,
      showInherited: showInherited,
      outputJSON: outputJSON,
      showAll: showAll
    )
  }
}
