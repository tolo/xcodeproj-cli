//
// RepairTargetsCommand.swift
// xcodeproj-cli
//
// ArgumentParser command for fixing common target-related issues
//

import ArgumentParser
import Foundation

/// ArgumentParser command for repairing targets
struct RepairTargetsCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "repair-targets",
    abstract:
      "Fix common target-related issues including missing product references and build phases"
  )

  @OptionGroup var global: GlobalOptions

  @Option(help: "Repair specific target (default: all targets)")
  var target: String?

  @MainActor
  func run() async throws {
    let services = try ProjectServiceFactory.create(from: global)
    let productManager = ProductReferenceManager(pbxproj: services.utility.pbxproj)

    print("🔍 Analyzing targets for issues...")

    let repaired = try productManager.repairTargets(targetName: target)

    if repaired.isEmpty {
      if let targetName = target {
        print("✅ Target '\(targetName)' is properly configured")
      } else {
        print("✅ All targets are properly configured")
      }
    } else {
      print("🔧 Repaired the following issues:")

      for issue in repaired {
        print("  • \(issue)")
      }

      try services.save()
      print("\n✅ Target repairs completed successfully")
    }
  }
}
