//
// ListTargetsCommand.swift
// xcodeproj-cli
//
// ArgumentParser command for listing all targets in the project
//

import ArgumentParser
import Foundation

/// ArgumentParser command for listing all targets in the project (read-only)
struct ListTargetsCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "list-targets",
    abstract: "List all targets in the project with their product types"
  )

  @OptionGroup var global: GlobalOptions

  @MainActor
  func run() async throws {
    let services = try ProjectServiceFactory.create(from: global, readOnly: true)

    print("📱 Targets in project:")
    for target in services.utility.pbxproj.nativeTargets {
      let productType = target.productType?.rawValue ?? "unknown"
      print("  - \(target.name) (\(productType))")
    }
  }
}
