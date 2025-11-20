//
// SetTestParallelCommand.swift
// xcodeproj-cli
//
// ArgumentParser command for setting test parallelization in schemes
//

import ArgumentParser
import Foundation
@preconcurrency import PathKit

/// ArgumentParser command for setting test parallelization
struct SetTestParallelCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "set-test-parallel",
    abstract: "Enable or disable test parallelization for a scheme"
  )

  @OptionGroup var global: GlobalOptions

  @Argument(help: "Name of the scheme to configure")
  var schemeName: String

  @Flag(help: "Enable test parallelization")
  var enable: Bool = false

  @Flag(help: "Disable test parallelization")
  var disable: Bool = false

  @MainActor
  func run() async throws {
    // Check for enable/disable flags
    if enable && disable {
      throw ProjectError.invalidArguments("Cannot specify both --enable and --disable")
    }

    if !enable && !disable {
      throw ProjectError.invalidArguments("Must specify either --enable or --disable")
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

    // Set test parallelization
    try schemeManager.setTestParallelization(
      schemeName: schemeName,
      enabled: enable
    )

    // Save changes
    try services.save()

    print("✅ \(enable ? "Enabled" : "Disabled") test parallelization for scheme '\(schemeName)'")

    if global.verbose {
      print("  Scheme: \(schemeName)")
      print("  Parallelization: \(enable ? "Enabled" : "Disabled")")
    }
  }
}
