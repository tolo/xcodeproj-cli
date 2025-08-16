//
// UpdatePathsMapCommand.swift
// xcodeproj-cli
//
// Command for updating file paths using a mapping of old to new paths
//

import Foundation
@preconcurrency import XcodeProj

/// Command for updating file paths using a mapping of old to new paths

struct UpdatePathsMapCommand: Command {
  static let commandName = "update-paths-map"

  static let description = "Update file paths using a mapping of old to new paths"

  static let category: CommandCategory = .pathOperations

  static func execute(with arguments: ParsedArguments, utility: XcodeProjUtility) throws {
    // Parse path mappings from positional arguments
    var mappings: [String: String] = [:]
    for arg in arguments.positional {
      let parts = arg.split(separator: ":")
      if parts.count == 2 {
        mappings[String(parts[0])] = String(parts[1])
      }
    }

    guard !mappings.isEmpty else {
      throw ProjectError.invalidArguments(
        "update-paths-map requires: <old1:new1> [old2:new2] ..."
      )
    }

    // Execute the command
    utility.updateFilePaths(mappings)
  }

  static func printUsage() {
    print(
      """
      update-paths-map <old1:new1> [old2:new2] ...
        Update file paths using a mapping of old to new paths
        
        Arguments:
          <oldN:newN>           Path mapping from old path to new path (colon-separated)
        
        Examples:
          update-paths-map "Sources/Old/File.swift:Sources/New/File.swift"
          update-paths-map "Old.swift:New.swift" "Helper.swift:Utils/Helper.swift"
        
        Notes:
          - Each mapping is applied independently
          - Exact path matching (not prefix-based like update-paths)
          - Useful for precise file relocations
          - Project is automatically saved after updates
      """)
  }
}

// MARK: - BaseCommand conformance
extension UpdatePathsMapCommand {
  // No additional BaseCommand methods needed for this simple command
}
