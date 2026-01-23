//
// AddGroupCommand.swift
// xcodeproj-cli
//

import ArgumentParser
import Foundation

/// Alias command for creating group hierarchies (backward compatibility with docs)
struct AddGroupCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "add-group",
    abstract: "Add empty virtual groups (alias of create-groups)",
    discussion: """
      Adds one or more virtual groups to the Xcode project. This is an alias of the create-groups command.

      Examples:
        xcodeproj-cli add-group UI/Components Services/API
        xcodeproj-cli add-group Architecture/Models Architecture/Views
      """
  )

  @OptionGroup var global: GlobalOptions

  @Argument(help: "One or more group paths to create")
  var groupPaths: [String]

  @MainActor
  func run() async throws {
    let services = try ProjectServiceFactory.create(from: global)
    try services.utility.createGroups(groupPaths)
    try services.save()

    for groupPath in groupPaths {
      print("✅ Created group hierarchy: \(groupPath)")
    }
  }
}
