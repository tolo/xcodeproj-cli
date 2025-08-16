//
// UpdateSwiftPackagesCommand.swift
// xcodeproj-cli
//
// Command for updating Swift Package dependencies to their latest versions
//

import Foundation
@preconcurrency import XcodeProj

/// Command for updating Swift Package dependencies to their latest versions

struct UpdateSwiftPackagesCommand: Command {
  static let commandName = "update-swift-packages"

  static let description = "Update Swift Package dependencies to their latest versions"

  static let category: CommandCategory = .swiftPackages

  static func execute(with arguments: ParsedArguments, utility: XcodeProjUtility) throws {
    let forceUpdate = arguments.hasFlag("--force", "-f")

    // Execute the command
    try utility.updateSwiftPackages(force: forceUpdate)

    // Save changes
    try utility.save()
  }

  static func printUsage() {
    print(
      """
      update-swift-packages [--force]
        Update Swift Package dependencies to their latest versions
        
        Options:
          --force, -f              Force update all packages regardless of version constraints
        
        Examples:
          update-swift-packages                # Update packages within version constraints
          update-swift-packages --force        # Force update all packages to latest
        
        Notes:
          - Lists current packages and their versions
          - Checks for available updates
          - Updates to latest compatible versions based on constraints
          - Reports what was updated after completion
          - Use --force to update beyond current version constraints
      """)
  }
}

// MARK: - BaseCommand conformance
extension UpdateSwiftPackagesCommand {
  // No additional BaseCommand methods needed for this command
}
