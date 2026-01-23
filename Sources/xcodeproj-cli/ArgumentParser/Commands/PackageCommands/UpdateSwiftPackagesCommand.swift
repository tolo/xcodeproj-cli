//
// UpdateSwiftPackagesCommand.swift
// xcodeproj-cli
//
// ArgumentParser command for updating Swift Package dependencies to their latest versions
//

import ArgumentParser
import Foundation

/// ArgumentParser command for updating Swift Package dependencies to their latest versions
struct UpdateSwiftPackagesCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "update-swift-packages",
    abstract: "Update Swift Package dependencies to their latest versions"
  )

  @OptionGroup var global: GlobalOptions

  @Flag(
    name: [.customLong("force"), .customShort("f")],
    help: "Force update all packages regardless of version constraints")
  var force = false

  @MainActor
  func run() async throws {
    let services = try ProjectServiceFactory.create(from: global)
    try services.utility.updateSwiftPackages(force: force)
    try services.save()

    let forceMsg = force ? " (forced)" : ""
    print("✅ Swift Packages updated\(forceMsg)")
  }
}
