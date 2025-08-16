//
// RemoveSwiftPackageCommand.swift
// xcodeproj-cli
//
// Command for removing Swift Package dependencies
//

import Foundation
@preconcurrency import XcodeProj

/// Command for removing Swift Package dependencies from the project

struct RemoveSwiftPackageCommand: Command {
  static let commandName = "remove-swift-package"

  static let description = "Remove Swift Package dependency from the project"

  static let category: CommandCategory = .swiftPackages

  static func execute(with arguments: ParsedArguments, utility: XcodeProjUtility) throws {
    // Validate required arguments
    try requirePositionalArguments(
      arguments,
      count: 1,
      usage: "remove-swift-package requires: <url>"
    )

    let url = arguments.positional[0]

    // Execute the command
    try utility.removeSwiftPackage(url: url)

    // Save changes
    try utility.save()
  }

  static func printUsage() {
    print(
      """
      remove-swift-package <url>
        Remove Swift Package dependency from the project
        
        Arguments:
          <url>  Package repository URL to remove
        
        Examples:
          remove-swift-package https://github.com/Alamofire/Alamofire.git
      """)
  }
}

// MARK: - BaseCommand conformance
extension RemoveSwiftPackageCommand {

  private static func requirePositionalArguments(
    _ arguments: ParsedArguments, count: Int, usage: String
  ) throws {
    try BaseCommand.requirePositionalArguments(arguments, count: count, usage: usage)
  }
}
