//
// CLIInterface.swift
// xcodeproj-cli
//
// Command-line interface definitions and help system
//

import Foundation

/// Main CLI interface for xcodeproj-cli
struct CLIInterface {
  static let version = "2.2.1"

  @MainActor
  static func printUsage() {
    // Print header
    print(
      """
      XcodeProj CLI v\(version)
      A powerful command-line tool for Xcode project manipulation

      Usage: xcodeproj-cli [--project <path>] <command> [options]

      Options:
        --project <path>  Path to .xcodeproj file (default: looks for *.xcodeproj in current directory)
        --dry-run         Preview changes without saving
        --verbose, -V     Enable verbose output with performance metrics
        --version         Display version information
        --help, -h        Show this help message

      ALL AVAILABLE COMMANDS:
      """
    )

    // Get command metadata from registry
    let commandsByCategory = CommandRegistry.getAllCommandMetadata()

    // Sort categories by display order
    let sortedCategories = CommandCategory.allCases.sorted { $0.displayOrder < $1.displayOrder }

    // Print commands by category
    for category in sortedCategories {
      guard let commands = commandsByCategory[category], !commands.isEmpty else { continue }

      print("\n\(category.rawValue):")

      // Find the longest command name for proper alignment
      let maxCommandLength = commands.map { $0.name.count }.max() ?? 0
      let padding = max(30, maxCommandLength + 2)

      // Sort commands alphabetically within each category
      let sortedCommands = commands.sorted { $0.name < $1.name }

      for command in sortedCommands {
        let paddedName = command.name.padding(toLength: padding, withPad: " ", startingAt: 0)
        print("  \(paddedName)  \(command.description)")
      }
    }

    // Print footer
    print(
      """

      For detailed usage of any command, use: xcodeproj-cli <command> --help
      Full documentation: https://github.com/tolo/xcodeproj-cli
      """
    )
  }

  static func printVersion() {
    print("xcodeproj-cli version \(version)")
  }
}
