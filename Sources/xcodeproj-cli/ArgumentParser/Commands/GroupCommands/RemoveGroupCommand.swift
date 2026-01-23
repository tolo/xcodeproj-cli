//
// RemoveGroupCommand.swift
// xcodeproj-cli
//
// ArgumentParser command for removing groups from the project
//

import ArgumentParser
import Foundation

/// ArgumentParser command for removing groups and their contents from the project
struct RemoveGroupCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "remove-group",
    abstract: "Remove a group and its contents from the project",
    discussion: """
      Removes a group and all its contents from the Xcode project.

      Warning: This removes the group and all its contents from the project.

      Examples:
        xcodeproj-cli remove-group Sources/Models
        xcodeproj-cli remove-group Utils
      """
  )

  @OptionGroup var global: GlobalOptions

  @Argument(help: "Path to the group to remove")
  var groupPath: String

  @MainActor
  func run() async throws {
    let services = try ProjectServiceFactory.create(from: global)

    // Execute the command
    try services.utility.removeGroup(groupPath)

    // Save changes
    try services.save()

    print("✅ Removed group: \(groupPath)")
  }
}
