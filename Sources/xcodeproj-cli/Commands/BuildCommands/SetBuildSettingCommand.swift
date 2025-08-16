//
// SetBuildSettingCommand.swift
// xcodeproj-cli
//
// Command for setting build settings on targets
//

import Foundation
@preconcurrency import XcodeProj

/// Command for setting build settings on specified targets

struct SetBuildSettingCommand: Command {
  static let commandName = "set-build-setting"

  static let description = "Set build setting on specified targets"

  static let category: CommandCategory = .buildConfiguration

  static func execute(with arguments: ParsedArguments, utility: XcodeProjUtility) throws {
    // Validate required arguments
    try BaseCommand.requirePositionalArguments(
      arguments,
      count: 2,
      usage: "set-build-setting requires: <key> <value> --targets <target1,target2>"
    )

    let key = arguments.positional[0]
    let value = arguments.positional[1]

    // Validate build setting for security
    guard SecurityUtils.validateBuildSetting(key: key, value: value) else {
      throw ProjectError.invalidArguments(
        "Build setting '\(key)' contains potentially dangerous value")
    }

    // Get required flags
    let targetsStr = try arguments.requireFlag(
      "--targets", "-t",
      error: "set-build-setting requires --targets or -t flag"
    )

    let targets = BaseCommand.parseTargets(from: targetsStr)
    let configuration = arguments.getFlag("--config", "-c")

    // Validate targets
    try BaseCommand.validateTargets(targets, in: utility)

    // Execute the command
    utility.setBuildSetting(key: key, value: value, targets: targets, configuration: configuration)

    // Save changes
    try utility.save()
  }

  static func printUsage() {
    print(
      """
      set-build-setting <key> <value> --targets <target1,target2> [--config <configuration>]
        Set build setting on specified targets
        
        Arguments:
          <key>                     Build setting key
          <value>                   Build setting value
          --targets, -t <list>      Comma-separated list of target names
          --config, -c <config>     Optional: specific configuration name
        
        Examples:
          set-build-setting SWIFT_VERSION 5.0 --targets MyApp,MyTests
          set-build-setting CODE_SIGN_IDENTITY "iPhone Developer" -t MyApp -c Debug
      """)
  }
}
