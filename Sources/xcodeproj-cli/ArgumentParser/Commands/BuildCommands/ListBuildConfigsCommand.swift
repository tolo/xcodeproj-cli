//
// ListBuildConfigsCommand.swift
// xcodeproj-cli
//

import ArgumentParser
import Foundation

/// ArgumentParser command for listing build configurations (read-only)
struct ListBuildConfigsCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "list-build-configs",
    abstract: "List build configurations for a target or the project",
    discussion: """
      List available build configurations. Without --target, shows project-level configurations.

      Examples:
        xcodeproj-cli list-build-configs                    # List project configurations
        xcodeproj-cli list-build-configs --target MyApp     # List configurations for MyApp target
      """
  )

  @OptionGroup var global: GlobalOptions

  @Option(
    name: [.customLong("target"), .customShort("t")],
    help: "Optional: target name (lists project configs if omitted)"
  )
  var targetName: String?

  @MainActor
  func run() async throws {
    // Create project services (read-only, no save needed)
    let services = try ProjectServiceFactory.create(from: global, readOnly: true)

    // If target is specified, validate it exists
    if let target = targetName {
      let projectTargets = Set(services.utility.pbxproj.nativeTargets.map { $0.name })
      guard projectTargets.contains(target) else {
        throw ProjectError.targetNotFound(target)
      }
    }

    // Execute the command
    services.utility.listBuildConfigurations(for: targetName)
  }
}
