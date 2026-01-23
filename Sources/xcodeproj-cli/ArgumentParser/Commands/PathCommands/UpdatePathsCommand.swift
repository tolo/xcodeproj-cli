//
// UpdatePathsCommand.swift
// xcodeproj-cli
//
// ArgumentParser command for updating file paths with prefix replacement
//

import ArgumentParser
import Foundation

/// ArgumentParser command for updating file paths using prefix replacement
struct UpdatePathsCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "update-paths",
    abstract: "Update file paths with prefix replacement"
  )

  @OptionGroup var global: GlobalOptions

  @Argument(help: "Old path prefix to replace")
  var oldPrefix: String

  @Argument(help: "New path prefix to use")
  var newPrefix: String

  @MainActor
  func run() async throws {
    let services = try ProjectServiceFactory.create(from: global)
    services.utility.updatePathsWithPrefix(from: oldPrefix, to: newPrefix)
    try services.save()
    print("✅ Updated file paths from '\(oldPrefix)' to '\(newPrefix)'")
  }
}
