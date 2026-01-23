//
// SetSchemeConfigCommand.swift
// xcodeproj-cli
//
// ArgumentParser command for configuring scheme settings
//

import ArgumentParser
import Foundation
@preconcurrency import PathKit

/// ArgumentParser command for setting scheme configurations
struct SetSchemeConfigCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "set-scheme-config",
    abstract: "Set build configurations for scheme actions"
  )

  @OptionGroup var global: GlobalOptions

  @Argument(help: "Name of the scheme to configure")
  var schemeName: String

  @Option(help: "Set build configuration")
  var build: String?

  @Option(help: "Set run configuration")
  var run: String?

  @Option(help: "Set test configuration")
  var test: String?

  @Option(help: "Set profile configuration")
  var profile: String?

  @Option(help: "Set analyze configuration")
  var analyze: String?

  @Option(help: "Set archive configuration")
  var archive: String?

  @MainActor
  func run() async throws {
    // Ensure at least one configuration is specified
    if build == nil && run == nil && test == nil && profile == nil && analyze == nil
      && archive == nil
    {
      throw ProjectError.invalidArguments("At least one configuration must be specified")
    }

    let services = try ProjectServiceFactory.create(from: global)
    let schemeManager = SchemeManager(
      xcodeproj: services.utility.xcodeproj,
      projectPath: services.utility.projectPath
    )

    // Check if scheme exists
    let existingSchemes = try schemeManager.listSchemes(shared: true)
    if !existingSchemes.contains(schemeName) {
      throw ProjectError.operationFailed("Scheme '\(schemeName)' not found")
    }

    // Update scheme configuration
    try schemeManager.setSchemeConfiguration(
      schemeName: schemeName,
      buildConfig: build,
      runConfig: run,
      testConfig: test,
      profileConfig: profile,
      analyzeConfig: analyze,
      archiveConfig: archive
    )

    // Save changes
    try services.save()

    print("✅ Updated scheme configuration for '\(schemeName)'")

    if global.verbose {
      print("  Updated configurations:")
      if let config = build { print("    Build: \(config)") }
      if let config = run { print("    Run: \(config)") }
      if let config = test { print("    Test: \(config)") }
      if let config = profile { print("    Profile: \(config)") }
      if let config = analyze { print("    Analyze: \(config)") }
      if let config = archive { print("    Archive: \(config)") }
    }
  }
}
