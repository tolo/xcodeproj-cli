//
// AddTargetCommand.swift
// xcodeproj-cli
//
// ArgumentParser command for adding a new target to the project
//

import ArgumentParser
import Foundation

/// ArgumentParser command for adding a new target to the project
struct AddTargetCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "add-target",
    abstract: "Add a new target to the project"
  )

  @OptionGroup var global: GlobalOptions

  @Argument(help: "Name of the new target")
  var name: String

  @Option(
    name: [.customLong("type"), .customShort("T")],
    help: """
      Product type (app, framework, test, etc.)

      Common types: app, framework, static-library, dynamic-library, test, ui-test
      """
  )
  var productType: String

  @Option(
    name: [.customLong("bundle-id"), .customShort("b")],
    help: "Bundle identifier for the target"
  )
  var bundleId: String

  @Option(
    name: [.customLong("platform"), .customShort("P")],
    help: "Target platform (default: iOS)"
  )
  var platform: String = "iOS"

  @MainActor
  func run() async throws {
    let services = try ProjectServiceFactory.create(from: global)
    try services.utility.addTarget(
      name: name,
      productType: productType,
      bundleId: bundleId,
      platform: platform
    )
    try services.save()
    print("✅ Target '\(name)' added successfully")
  }
}
