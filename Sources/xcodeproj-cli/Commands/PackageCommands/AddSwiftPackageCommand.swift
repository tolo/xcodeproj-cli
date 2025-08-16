//
// AddSwiftPackageCommand.swift
// xcodeproj-cli
//
// Command for adding Swift Package dependencies
//

import Foundation
@preconcurrency import XcodeProj

/// Command for adding Swift Package dependencies to the project

struct AddSwiftPackageCommand: Command {
  static let commandName = "add-swift-package"

  static let description = "Add Swift Package dependency to the project"

  static let category: CommandCategory = .swiftPackages

  static func execute(with arguments: ParsedArguments, utility: XcodeProjUtility) throws {
    // Validate required arguments
    try requirePositionalArguments(
      arguments,
      count: 1,
      usage: "add-swift-package requires: <url> --version <requirement> [--target <target>]"
    )

    let url = arguments.positional[0]

    // Check for conflicting flags
    let versionFlag = arguments.getFlag("--version", "-v")
    let branchFlag = arguments.getFlag("--branch", "-b")
    let commitFlag = arguments.getFlag("--commit", "-c")

    let versionFlags = [versionFlag, branchFlag, commitFlag].compactMap { $0 }
    if versionFlags.count > 1 {
      throw ProjectError.invalidArguments(
        "Cannot specify multiple version requirements (--version, --branch, --commit are mutually exclusive)"
      )
    }

    // Get requirement (version, branch, or commit)
    let requirement: String
    if let version = versionFlag {
      requirement = version.hasPrefix("from:") || version.hasPrefix("exact:") ? version : version
    } else if let branch = branchFlag {
      requirement = "branch:\(branch)"
    } else if let commit = commitFlag {
      requirement = "commit:\(commit)"
    } else {
      throw ProjectError.invalidArguments(
        "add-swift-package requires one of: --version, --branch, or --commit flag")
    }

    let targetName = arguments.getFlag("--target", "-t")

    // If target is specified, validate it exists
    if let target = targetName {
      try validateTargets([target], in: utility)
    }

    // Execute the command
    try utility.addSwiftPackage(url: url, requirement: requirement, to: targetName)

    // Save changes
    try utility.save()
  }

  static func printUsage() {
    print(
      """
      add-swift-package <url> (--version <req> | --branch <branch> | --commit <hash>) [--target <target>]
        Add Swift Package dependency to the project
        
        Arguments:
          <url>                     Package repository URL (https:// or git@)
          --version, -v <req>       Version requirement (e.g., "1.0.0", "from: 1.0.0")
          --branch, -b <branch>     Branch requirement (e.g., "main", "develop")
          --commit, -c <hash>       Commit hash requirement
          --target, -t <target>     Optional: target to add package to
        
        Note: --version, --branch, and --commit are mutually exclusive
        
        Examples:
          add-swift-package https://github.com/Alamofire/Alamofire.git --version "from: 5.0.0"
          add-swift-package https://github.com/realm/realm-swift.git --branch "master" -t MyApp
      """)
  }
}

// MARK: - BaseCommand conformance
extension AddSwiftPackageCommand {

  private static func requirePositionalArguments(
    _ arguments: ParsedArguments, count: Int, usage: String
  ) throws {
    try BaseCommand.requirePositionalArguments(arguments, count: count, usage: usage)
  }

  @MainActor
  private static func validateTargets(_ targetNames: [String], in utility: XcodeProjUtility) throws
  {
    try BaseCommand.validateTargets(targetNames, in: utility)
  }
}
