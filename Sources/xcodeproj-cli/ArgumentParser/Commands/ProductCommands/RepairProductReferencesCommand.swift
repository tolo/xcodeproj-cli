//
// RepairProductReferencesCommand.swift
// xcodeproj-cli
//
// ArgumentParser command for automatically detecting and fixing missing or broken product references
//

import ArgumentParser
import Foundation

/// ArgumentParser command for repairing product references
struct RepairProductReferencesCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "repair-product-references",
    abstract: "Automatically detect and fix missing or broken product references for all targets"
  )

  @OptionGroup var global: GlobalOptions

  @Option(
    help: "Comma-separated list of specific targets to repair",
    transform: { $0.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) } }
  )
  var targets: [String]?

  @MainActor
  func run() async throws {
    let services = try ProjectServiceFactory.create(from: global)
    let productManager = ProductReferenceManager(pbxproj: services.utility.pbxproj)

    print("🔍 Analyzing product references...")

    let repaired = try productManager.repairProductReferences(
      dryRun: global.dryRun,
      targetNames: targets
    )

    if repaired.isEmpty {
      print("✅ All product references are properly configured")
    } else {
      if global.dryRun {
        print("🔧 Would repair the following issues (dry run):")
      } else {
        print("🔧 Repaired the following issues:")
      }

      for issue in repaired {
        print("  • \(issue)")
      }

      if !global.dryRun {
        try services.save()
        print("✅ Product references repaired successfully")
      } else {
        print("💡 Run without --dry-run to apply fixes")
      }
    }
  }
}
