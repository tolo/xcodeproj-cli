//
// DuplicateSchemeCommand.swift
// xcodeproj-cli
//
// Command for duplicating Xcode schemes
//

import Foundation
@preconcurrency import PathKit
@preconcurrency import XcodeProj

struct DuplicateSchemeCommand: Command {
  static let commandName = "duplicate-scheme"
  static let description = "Duplicate an existing scheme"

  static let category: CommandCategory = .schemes

  let sourceName: String
  let destinationName: String
  let verbose: Bool

  init(arguments: ParsedArguments) throws {
    guard arguments.positional.count >= 2 else {
      throw ProjectError.invalidArguments("Source and destination scheme names are required")
    }

    self.sourceName = arguments.positional[0]
    self.destinationName = arguments.positional[1]
    self.verbose = arguments.boolFlags.contains("--verbose")
  }

  @MainActor
  func execute(with xcodeproj: XcodeProj, projectPath: Path) throws {
    let schemeManager = SchemeManager(xcodeproj: xcodeproj, projectPath: projectPath)

    // Check if source scheme exists
    let existingSchemes = try schemeManager.listSchemes(shared: true)
    if !existingSchemes.contains(sourceName) {
      throw ProjectError.schemeNotFound(sourceName)
    }

    // Check if destination scheme already exists
    if existingSchemes.contains(destinationName) {
      throw ProjectError.operationFailed("Destination scheme '\(destinationName)' already exists")
    }

    // Duplicate the scheme
    _ = try schemeManager.duplicateScheme(
      sourceName: sourceName,
      destinationName: destinationName
    )

    print("✅ Duplicated scheme '\(sourceName)' to '\(destinationName)'")

    if verbose {
      print("  Source: \(sourceName)")
      print("  Destination: \(destinationName)")
    }
  }

  static func execute(with arguments: ParsedArguments, utility: XcodeProjUtility) throws {
    let cmd = try DuplicateSchemeCommand(arguments: arguments)
    try cmd.execute(with: utility.xcodeproj, projectPath: utility.projectPath)
  }

  static func printUsage() {
    print(
      """
      Usage: duplicate-scheme <source> <destination> [options]

      Arguments:
        source            Name of the scheme to duplicate
        destination       Name for the new scheme

      Options:
        --verbose         Show detailed output

      Examples:
        duplicate-scheme MyApp MyAppDev
        duplicate-scheme Production Staging
      """)
  }
}
