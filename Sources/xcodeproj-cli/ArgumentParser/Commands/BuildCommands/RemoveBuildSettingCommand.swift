//
// RemoveBuildSettingCommand.swift
// xcodeproj-cli
//

import ArgumentParser
import Foundation

/// ArgumentParser command for removing build settings from targets
struct RemoveBuildSettingCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "remove-build-setting",
    abstract: "Remove build setting from specified targets",
    discussion: """
      Remove a build setting key from one or more targets.

      Examples:
        xcodeproj-cli remove-build-setting SWIFT_VERSION --targets MyApp,MyTests
        xcodeproj-cli remove-build-setting CODE_SIGN_IDENTITY -t MyApp -c Debug
      """
  )

  @OptionGroup var global: GlobalOptions

  @Argument(help: "Build setting key to remove")
  var key: String

  @Option(
    name: [.customLong("targets"), .customShort("t")],
    help: "Comma-separated list of target names",
    transform: { $0.split(separator: ",").map(String.init) }
  )
  var targets: [String]

  @Option(
    name: [.customLong("config"), .customShort("c")],
    help: "Optional: specific configuration name"
  )
  var configuration: String?

  @MainActor
  func run() async throws {
    // Create project services
    let services = try ProjectServiceFactory.create(from: global)

    // Validate targets
    let projectTargets = Set(services.utility.pbxproj.nativeTargets.map { $0.name })
    for targetName in targets {
      guard projectTargets.contains(targetName) else {
        throw ProjectError.targetNotFound(targetName)
      }
    }

    // Execute the command
    services.utility.removeBuildSetting(
      key: key,
      targets: targets,
      configuration: configuration
    )

    // Save changes
    try services.save()

    if global.verbose {
      print(
        "✅ Build setting '\(key)' removed from targets: \(targets.joined(separator: ", "))"
      )
      if let config = configuration {
        print("   Configuration: \(config)")
      }
    }
  }
}
