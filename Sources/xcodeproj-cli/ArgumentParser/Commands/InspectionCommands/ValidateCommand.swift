//
// ValidateCommand.swift
// xcodeproj-cli
//
// ArgumentParser command for validating project integrity
//

import ArgumentParser
import Foundation

/// ArgumentParser command for validating project integrity
struct ValidateCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "validate",
    abstract: "Validate project integrity"
  )

  @OptionGroup var global: GlobalOptions

  @Flag(
    name: [.customLong("fix")],
    help: "Automatically fix some validation issues")
  var fix = false

  @MainActor
  func run() async throws {
    // Read-only mode unless --fix is specified
    let services = try ProjectServiceFactory.create(from: global, readOnly: !fix)
    let issues = services.utility.validate()

    if issues.isEmpty {
      print("✅ No validation issues found")
    } else {
      print("⚠️  Found \(issues.count) validation issue(s):")
      for issue in issues {
        print("  - \(issue)")
      }

      if fix {
        print("\n🔧 Attempting to fix issues...")
        services.utility.removeInvalidReferences()
        try services.save()
        print("✅ Fixed invalid references")
      } else {
        print("\nUse --fix to automatically fix some issues")
      }
    }
  }
}
