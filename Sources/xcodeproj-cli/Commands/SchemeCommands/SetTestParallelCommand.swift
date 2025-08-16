//
// SetTestParallelCommand.swift
// xcodeproj-cli
//
// Command for setting test parallelization in schemes
//

import Foundation
@preconcurrency import PathKit
@preconcurrency import XcodeProj

struct SetTestParallelCommand: Command {
  static let commandName = "set-test-parallel"
  static let description = "Enable or disable test parallelization for a scheme"

  static let category: CommandCategory = .schemes

  let schemeName: String
  let enabled: Bool
  let verbose: Bool

  init(arguments: ParsedArguments) throws {
    guard let name = arguments.positional.first else {
      throw ProjectError.invalidArguments("Scheme name is required")
    }

    self.schemeName = name

    // Check for enable/disable flags
    let hasEnable = arguments.boolFlags.contains("--enable")
    let hasDisable = arguments.boolFlags.contains("--disable")

    if hasEnable && hasDisable {
      throw ProjectError.invalidArguments("Cannot specify both --enable and --disable")
    }

    if !hasEnable && !hasDisable {
      throw ProjectError.invalidArguments("Must specify either --enable or --disable")
    }

    self.enabled = hasEnable
    self.verbose = arguments.boolFlags.contains("--verbose")
  }

  @MainActor
  func execute(with xcodeproj: XcodeProj, projectPath: Path) throws {
    let schemeManager = SchemeManager(xcodeproj: xcodeproj, projectPath: projectPath)

    // Check if scheme exists
    let existingSchemes = try schemeManager.listSchemes(shared: true)
    if !existingSchemes.contains(schemeName) {
      throw ProjectError.operationFailed("Scheme '\(schemeName)' not found")
    }

    // Set test parallelization
    try schemeManager.setTestParallelization(
      schemeName: schemeName,
      enabled: enabled
    )

    print("✅ \(enabled ? "Enabled" : "Disabled") test parallelization for scheme '\(schemeName)'")

    if verbose {
      print("  Scheme: \(schemeName)")
      print("  Parallelization: \(enabled ? "Enabled" : "Disabled")")
    }
  }

  static func printUsage() {
    print(
      """
      Usage: set-test-parallel <scheme> [options]

      Arguments:
        scheme            Name of the scheme to configure

      Options:
        --enable          Enable test parallelization
        --disable         Disable test parallelization
        --verbose         Show detailed output

      Examples:
        set-test-parallel MyApp --enable
        set-test-parallel MyApp --disable --verbose
      """)
  }

  static func execute(with arguments: ParsedArguments, utility: XcodeProjUtility) throws {
    let cmd = try SetTestParallelCommand(arguments: arguments)
    try cmd.execute(with: utility.xcodeproj, projectPath: utility.projectPath)
  }
}
