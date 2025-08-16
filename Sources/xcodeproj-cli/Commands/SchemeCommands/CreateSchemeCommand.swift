//
// CreateSchemeCommand.swift
// xcodeproj-cli
//
// Command for creating Xcode schemes
//

import Foundation
@preconcurrency import PathKit
@preconcurrency import XcodeProj

struct CreateSchemeCommand: Command {
  static let commandName = "create-scheme"
  static let description = "Create a new scheme for a target"

  static let category: CommandCategory = .schemes

  @MainActor
  static func execute(with arguments: ParsedArguments, utility: XcodeProjUtility) throws {
    guard let schemeName = arguments.positional.first else {
      throw ProjectError.invalidArguments("Scheme name is required")
    }

    let targetName = arguments.getFlag("--target", "target") ?? schemeName
    let shared = arguments.boolFlags.contains("--shared") || !arguments.boolFlags.contains("--user")
    let verbose = arguments.boolFlags.contains("--verbose")

    let schemeManager = SchemeManager(
      xcodeproj: utility.xcodeproj, projectPath: utility.projectPath)

    // Check if scheme already exists
    let existingSchemes = try schemeManager.listSchemes(shared: shared)
    if existingSchemes.contains(schemeName) {
      throw ProjectError.operationFailed("Scheme '\(schemeName)' already exists")
    }

    // Create the scheme
    _ = try schemeManager.createScheme(
      name: schemeName,
      targetName: targetName,
      shared: shared
    )

    print("✅ Created scheme '\(schemeName)' for target '\(targetName)'")

    if verbose {
      print("  Location: \(shared ? "Shared" : "User")")
      print("  Target: \(targetName)")
    }
  }

  static func printUsage() {
    print(
      """
      Usage: create-scheme <name> [options]

      Arguments:
        name              Name of the scheme to create

      Options:
        --target <name>   Target to create scheme for (default: scheme name)
        --shared          Create as shared scheme (default)
        --user            Create as user-specific scheme
        --verbose         Show detailed output

      Examples:
        create-scheme MyApp --target MyApp
        create-scheme MyAppDev --target MyApp --shared
      """)
  }
}
