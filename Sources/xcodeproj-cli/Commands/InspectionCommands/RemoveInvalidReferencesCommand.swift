//
// RemoveInvalidReferencesCommand.swift
// xcodeproj-cli
//
// Command for removing invalid file references from the project
//

import Foundation
@preconcurrency import XcodeProj

/// Command for removing invalid file references from the project

struct RemoveInvalidReferencesCommand: Command {
  static let commandName = "remove-invalid-references"

  static let description = "Remove invalid file references from the project"

  static let category: CommandCategory = .inspection

  static func execute(with arguments: ParsedArguments, utility: XcodeProjUtility) throws {
    // Execute the command
    utility.removeInvalidReferences()
  }

  static func printUsage() {
    print(
      """
      remove-invalid-references
        Remove invalid file references from the project
        
        Examples:
          remove-invalid-references
        
        Notes:
          - Removes files referenced in project but missing from filesystem
          - Automatically cleans up broken references
          - Use list-invalid-references first to see what will be removed
          - Project is automatically saved after cleanup
      """)
  }
}
