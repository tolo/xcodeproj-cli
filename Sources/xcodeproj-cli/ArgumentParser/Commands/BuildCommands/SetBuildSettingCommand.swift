//
// SetBuildSettingCommand.swift
// xcodeproj-cli
//

import ArgumentParser
import Foundation

/// ArgumentParser command for setting build settings on targets
struct SetBuildSettingCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "set-build-setting",
    abstract: "Set build setting on specified targets",
    discussion: """
      Set a build setting key-value pair on one or more targets.

      Examples:
        xcodeproj-cli set-build-setting SWIFT_VERSION 5.0 --targets MyApp,MyTests
        xcodeproj-cli set-build-setting CODE_SIGN_IDENTITY "iPhone Developer" -t MyApp -c Debug
      """
  )

  @OptionGroup var global: GlobalOptions

  @Argument(help: "Build setting key")
  var key: String

  @Argument(help: "Build setting value")
  var value: String

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
    // Validate build setting for security
    guard SecurityUtils.validateBuildSetting(key: key, value: value) else {
      throw ProjectError.invalidArguments(
        "Build setting '\(key)' contains potentially dangerous value")
    }

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
    services.utility.setBuildSetting(
      key: key,
      value: value,
      targets: targets,
      configuration: configuration
    )

    // Save changes
    try services.save()

    if global.verbose {
      print(
        "✅ Build setting '\(key)' set to '\(value)' for targets: \(targets.joined(separator: ", "))"
      )
      if let config = configuration {
        print("   Configuration: \(config)")
      }
    }
  }
}
