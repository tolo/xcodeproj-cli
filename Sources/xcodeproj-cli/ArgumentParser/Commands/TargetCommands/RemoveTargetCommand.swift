//
// RemoveTargetCommand.swift
// xcodeproj-cli
//
// ArgumentParser command for removing a target from the project
//

import ArgumentParser
import Foundation

/// ArgumentParser command for removing a target from the project
struct RemoveTargetCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "remove-target",
    abstract: "Remove a target from the project"
  )

  @OptionGroup var global: GlobalOptions

  @Argument(help: "Name of the target to remove")
  var targetName: String

  @MainActor
  func run() async throws {
    let services = try ProjectServiceFactory.create(from: global)
    try services.utility.removeTarget(name: targetName)
    try services.save()
    print("✅ Target '\(targetName)' removed successfully")
  }
}
