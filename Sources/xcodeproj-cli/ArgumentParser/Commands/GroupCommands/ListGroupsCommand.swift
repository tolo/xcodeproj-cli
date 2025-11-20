//
// ListGroupsCommand.swift
// xcodeproj-cli
//
// ArgumentParser command for listing groups in the project
//

import ArgumentParser
import Foundation

/// ArgumentParser command for listing groups in a tree structure
struct ListGroupsCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "list-groups",
    abstract: "List groups in the project as a tree structure",
    discussion: """
      Lists all groups in the Xcode project as a tree structure.
      By default shows a tree structure. Use --show-names to see both simple names
      and full paths for use with other commands.

      Examples:
        xcodeproj-cli list-groups
        xcodeproj-cli list-groups --show-names
      """
  )

  @OptionGroup var global: GlobalOptions

  @Flag(name: .long, help: "Show both tree structure and usable names")
  var showNames: Bool = false

  @MainActor
  func run() async throws {
    let services = try ProjectServiceFactory.create(from: global, readOnly: true)

    // List groups (read-only operation, no save needed)
    if showNames {
      services.utility.listGroupsWithNames()
    } else {
      services.utility.listGroupsTree()
    }
  }
}
