//
// ListTreeCommand.swift
// xcodeproj-cli
//
// Command for listing the project structure as a tree
//

import Foundation
@preconcurrency import XcodeProj

/// Command for listing the complete project structure as a tree

struct ListTreeCommand: Command {
  static let commandName = "list-tree"

  static let description = "List the complete project structure as a tree"

  static let category: CommandCategory = .inspection

  static let isReadOnly = true

  static func execute(with arguments: ParsedArguments, utility: XcodeProjUtility) throws {
    let targetName = arguments.getFlag("--target", "-t")

    if let targetName = targetName {
      try utility.listTargetTree(targetName: targetName)
    } else {
      utility.listProjectTree()
    }
  }

  static func printUsage() {
    print(
      """
      list-tree [--target <target-name>]
        List the complete project structure as a tree
        
        Arguments:
          --target, -t <name>   Optional: show tree for files in specified target only
        
        Examples:
          list-tree                  # Show complete project tree
          list-tree --target MyApp   # Show tree of files in MyApp target
          list-tree -t MyAppTests    # Show tree of files in MyAppTests target
        
        Note: Shows complete project structure including files and groups
      """)
  }
}

// MARK: - BaseCommand conformance
extension ListTreeCommand {
  // No additional BaseCommand methods needed for this command
}
