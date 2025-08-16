//
// ListGroupsCommand.swift
// xcodeproj-cli
//
// Command for listing groups in the project
//

import Foundation
@preconcurrency import XcodeProj

/// Command for listing groups in a tree structure

struct ListGroupsCommand: Command {
  static let commandName = "list-groups"

  static let description = "List groups in the project as a tree structure"

  static let category: CommandCategory = .groupOperations

  static let isReadOnly = true
  static func execute(with arguments: ParsedArguments, utility: XcodeProjUtility) throws {
    utility.listGroupsTree()
  }

  static func printUsage() {
    print(
      """
      list-groups
        List groups in the project as a tree structure
        
        Examples:
          list-groups
        
        Note: Shows only groups, not individual files
      """)
  }
}

// MARK: - BaseCommand conformance
extension ListGroupsCommand {
  // No additional BaseCommand methods needed for this command
}
