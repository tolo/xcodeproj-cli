//
// SetSchemeConfigCommand.swift
// xcodeproj-cli
//
// Command for configuring scheme settings
//

import Foundation
@preconcurrency import PathKit
@preconcurrency import XcodeProj

struct SetSchemeConfigCommand: Command {
  static let commandName = "set-scheme-config"
  static let description = "Set build configurations for scheme actions"

  static let category: CommandCategory = .schemes

  let schemeName: String
  let buildConfig: String?
  let runConfig: String?
  let testConfig: String?
  let profileConfig: String?
  let analyzeConfig: String?
  let archiveConfig: String?
  let verbose: Bool

  init(arguments: ParsedArguments) throws {
    guard let name = arguments.positional.first else {
      throw ProjectError.invalidArguments("Scheme name is required")
    }

    self.schemeName = name
    self.buildConfig = arguments.getFlag("--build", "build")
    self.runConfig = arguments.getFlag("--run", "run")
    self.testConfig = arguments.getFlag("--test", "test")
    self.profileConfig = arguments.getFlag("--profile", "profile")
    self.analyzeConfig = arguments.getFlag("--analyze", "analyze")
    self.archiveConfig = arguments.getFlag("--archive", "archive")
    self.verbose = arguments.boolFlags.contains("--verbose")

    // Ensure at least one configuration is specified
    if buildConfig == nil && runConfig == nil && testConfig == nil && profileConfig == nil
      && analyzeConfig == nil && archiveConfig == nil
    {
      throw ProjectError.invalidArguments("At least one configuration must be specified")
    }
  }

  @MainActor
  func execute(with xcodeproj: XcodeProj, projectPath: Path) throws {
    let schemeManager = SchemeManager(xcodeproj: xcodeproj, projectPath: projectPath)

    // Check if scheme exists
    let existingSchemes = try schemeManager.listSchemes(shared: true)
    if !existingSchemes.contains(schemeName) {
      throw ProjectError.operationFailed("Scheme '\(schemeName)' not found")
    }

    // Update scheme configuration
    try schemeManager.setSchemeConfiguration(
      schemeName: schemeName,
      buildConfig: buildConfig,
      runConfig: runConfig,
      testConfig: testConfig,
      profileConfig: profileConfig,
      analyzeConfig: analyzeConfig,
      archiveConfig: archiveConfig
    )

    if verbose {
      print("  Updated configurations:")
      if let config = buildConfig { print("    Build: \(config)") }
      if let config = runConfig { print("    Run: \(config)") }
      if let config = testConfig { print("    Test: \(config)") }
      if let config = profileConfig { print("    Profile: \(config)") }
      if let config = analyzeConfig { print("    Analyze: \(config)") }
      if let config = archiveConfig { print("    Archive: \(config)") }
    }
  }

  static func printUsage() {
    print(
      """
      Usage: set-scheme-config <scheme> [options]

      Arguments:
        scheme            Name of the scheme to configure

      Options:
        --build <config>    Set build configuration
        --run <config>      Set run configuration
        --test <config>     Set test configuration
        --profile <config>  Set profile configuration
        --analyze <config>  Set analyze configuration
        --archive <config>  Set archive configuration
        --verbose           Show detailed output

      Examples:
        set-scheme-config MyApp --run Debug --test Debug --archive Release
        set-scheme-config Production --run Release --archive Release
      """)
  }

  static func execute(with arguments: ParsedArguments, utility: XcodeProjUtility) throws {
    let cmd = try SetSchemeConfigCommand(arguments: arguments)
    try cmd.execute(with: utility.xcodeproj, projectPath: utility.projectPath)
  }
}
