//
// DuplicateTargetCommand.swift
// xcodeproj-cli
//
// ArgumentParser command for duplicating an existing target with a new name
//

import ArgumentParser
import Foundation

/// ArgumentParser command for duplicating an existing target with optional bundle ID override
struct DuplicateTargetCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "duplicate-target",
    abstract: "Duplicate an existing target with a new name"
  )

  @OptionGroup var global: GlobalOptions

  @Argument(help: "Name of the target to duplicate")
  var sourceTarget: String

  @Argument(help: "Name for the new target")
  var newName: String

  @Option(
    name: [.customLong("bundle-id"), .customShort("b")],
    help: "Optional new bundle identifier (defaults to source target's bundle ID)"
  )
  var bundleId: String?

  @MainActor
  func run() async throws {
    let services = try ProjectServiceFactory.create(from: global)
    try services.utility.duplicateTarget(
      source: sourceTarget,
      newName: newName,
      newBundleId: bundleId
    )
    try services.save()
    print("✅ Target '\(sourceTarget)' duplicated to '\(newName)'")
  }
}
