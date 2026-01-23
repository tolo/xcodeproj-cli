//
// CreateGroupsCommand.swift
// xcodeproj-cli
//
// ArgumentParser command for creating group hierarchies
//

import ArgumentParser
import Foundation

/// ArgumentParser command for creating group hierarchies in the project
struct CreateGroupsCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "create-groups",
    abstract: "Create group hierarchies in the project",
    discussion: """
      Creates one or more group hierarchies in the Xcode project.
      Group paths support nested hierarchies with forward slashes.

      Examples:
        # Create simple groups
        xcodeproj-cli create-groups Models Views

        # Create nested structures
        xcodeproj-cli create-groups Sources/Models Sources/Views
        xcodeproj-cli create-groups Utils/Network Utils/Storage

        # Real-world iOS app structure
        xcodeproj-cli create-groups \\
          MyApp/Source/Application \\
          MyApp/Source/Features/Authentication/Views \\
          MyApp/Source/Features/Authentication/ViewModels \\
          MyApp/Resources

      To see created groups:
        xcodeproj-cli list-groups --show-names
      """
  )

  @OptionGroup var global: GlobalOptions

  @Argument(help: "One or more group paths to create")
  var groupPaths: [String]

  @MainActor
  func run() async throws {
    let services = try ProjectServiceFactory.create(from: global)

    // Create all specified groups
    try services.utility.createGroups(groupPaths)

    // Save changes
    try services.save()

    for groupPath in groupPaths {
      print("✅ Created group hierarchy: \(groupPath)")
    }
  }
}
