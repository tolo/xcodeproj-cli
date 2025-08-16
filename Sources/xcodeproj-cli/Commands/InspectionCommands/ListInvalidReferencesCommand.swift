//
// ListInvalidReferencesCommand.swift
// xcodeproj-cli
//
// Command for listing invalid file references in the project
//

import Foundation
@preconcurrency import XcodeProj

/// Command for listing invalid file references in the project

struct ListInvalidReferencesCommand: Command {
  static let commandName = "list-invalid-references"

  static let description = "List invalid file references in the project"

  static let category: CommandCategory = .inspection

  static let isReadOnly = true
  static func execute(with arguments: ParsedArguments, utility: XcodeProjUtility) throws {
    // Execute the command
    utility.listInvalidReferences()
  }

  static func printUsage() {
    print(
      """
      list-invalid-references
        List invalid file references in the project
        
        Examples:
          list-invalid-references
        
        Notes:
          - Shows files referenced in project but missing from filesystem
          - Helps identify broken references that need cleanup
          - Use remove-invalid-references to clean up automatically
      """)
  }
}
