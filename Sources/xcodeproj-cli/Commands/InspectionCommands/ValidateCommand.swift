//
// ValidateCommand.swift
// xcodeproj-cli
//
// Command for validating project integrity
//

import Foundation
@preconcurrency import XcodeProj

/// Command for validating project integrity

struct ValidateCommand: Command {
  static let commandName = "validate"

  static let description = "Validate project integrity"

  static let category: CommandCategory = .inspection

  static let isReadOnly = true
  static func execute(with arguments: ParsedArguments, utility: XcodeProjUtility) throws {
    let issues = utility.validate()

    if issues.isEmpty {
      print("✅ No validation issues found")
    } else {
      print("⚠️  Found \(issues.count) validation issues:")
      for issue in issues {
        print("  - \(issue)")
      }

      // Check if auto-fix is requested
      if arguments.hasFlag("--fix") {
        print("\n🔧 Attempting to fix issues...")
        utility.removeInvalidReferences()
        try utility.save()
        print("✅ Fixed invalid references")
      } else {
        print("\nUse --fix to automatically fix some issues")
      }
    }
  }

  static func printUsage() {
    print(
      """
      validate [--fix]
        Validate project integrity
        
        Options:
          --fix  Automatically fix some validation issues
        
        Examples:
          validate           # Check for issues
          validate --fix     # Check and fix issues
      """)
  }
}

// MARK: - BaseCommand conformance
extension ValidateCommand {
  // No additional BaseCommand methods needed for this command
}
