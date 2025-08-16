//
// RemoveSchemeCommand.swift
// xcodeproj-cli
//
// Command for removing Xcode schemes
//

import Foundation
@preconcurrency import PathKit
@preconcurrency import XcodeProj

struct RemoveSchemeCommand: Command {
  static let commandName = "remove-scheme"
  static let description = "Remove a scheme"

  static let category: CommandCategory = .schemes

  let schemeName: String
  let verbose: Bool

  init(arguments: ParsedArguments) throws {
    guard let name = arguments.positional.first else {
      throw ProjectError.invalidArguments("Scheme name is required")
    }

    self.schemeName = name
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

    // Remove the scheme
    try schemeManager.removeScheme(name: schemeName)

    if verbose {
      print("  Removed: \(schemeName)")
    }
  }

  static func printUsage() {
    print(
      """
      Usage: remove-scheme <name> [options]

      Arguments:
        name              Name of the scheme to remove

      Options:
        --verbose         Show detailed output

      Examples:
        remove-scheme OldScheme
        remove-scheme TestScheme --verbose
      """)
  }

  static func execute(with arguments: ParsedArguments, utility: XcodeProjUtility) throws {
    let cmd = try RemoveSchemeCommand(arguments: arguments)
    try cmd.execute(with: utility.xcodeproj, projectPath: utility.projectPath)
  }
}
