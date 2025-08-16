//
// CreateGroupsCommand.swift
// xcodeproj-cli
//
// Command for creating group hierarchies
//

import Foundation
@preconcurrency import XcodeProj

/// Command for creating group hierarchies in the project

struct CreateGroupsCommand: Command {
  static let commandName = "create-groups"

  static let description = "Create group hierarchies in the project"

  static let category: CommandCategory = .groupOperations

  static func execute(with arguments: ParsedArguments, utility: XcodeProjUtility) throws {
    // Validate required arguments
    guard !arguments.positional.isEmpty else {
      throw ProjectError.invalidArguments("create-groups requires: <group1> [group2] ...")
    }

    // Create all specified groups
    utility.createGroups(arguments.positional)

    // Save changes
    try utility.save()

    for groupPath in arguments.positional {
      print("✅ Created group hierarchy: \(groupPath)")
    }
  }

  static func printUsage() {
    print(
      """
      create-groups <group1> [group2] ...
        Create group hierarchies in the project
        
        Arguments:
          <group1> [group2] ...  One or more group paths to create
        
        Examples:
          create-groups Sources/Models Sources/Views
          create-groups Utils/Network Utils/Storage
        
        Note: Group paths support nested hierarchies with forward slashes
      """)
  }
}

// MARK: - BaseCommand conformance
extension CreateGroupsCommand {
  // No additional BaseCommand methods needed for this command
}
