//
// ListTargetsCommand.swift
// xcodeproj-cli
//
// Command for listing all targets in the project
//

import Foundation
@preconcurrency import XcodeProj

/// Command for listing all targets in the project

struct ListTargetsCommand: Command {
  static let commandName = "list-targets"

  static let description = "List all targets in the project"

  static let category: CommandCategory = .targetManagement

  static let isReadOnly = true
  static func execute(with arguments: ParsedArguments, utility: XcodeProjUtility) throws {
    print("📱 Targets in project:")

    for target in utility.pbxproj.nativeTargets {
      let productType = target.productType?.rawValue ?? "unknown"
      print("  - \(target.name) (\(productType))")
    }

    // This command should exit after listing since it's read-only
    exit(0)
  }

  static func printUsage() {
    print(
      """
      list-targets
        List all targets in the project with their product types
        
        Output format:
          - TargetName (product-type)
        
        Example output:
          📱 Targets in project:
            - MyApp (application)
            - MyAppTests (unit-test-bundle)
            - MyFramework (framework)
      """)
  }
}

// MARK: - BaseCommand conformance
extension ListTargetsCommand {
  // No additional BaseCommand methods needed for this simple command
}
