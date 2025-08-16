//
// AddBuildPhaseCommand.swift
// xcodeproj-cli
//
// Command for adding a build phase to a target
//

import Foundation
@preconcurrency import XcodeProj

/// Command for adding a build phase to a target

struct AddBuildPhaseCommand: Command {
  static let commandName = "add-build-phase"

  static let description = "Add a build phase to a target"

  static let category: CommandCategory = .buildConfiguration

  static func execute(with arguments: ParsedArguments, utility: XcodeProjUtility) throws {
    // Validate required arguments
    try requirePositionalArguments(
      arguments,
      count: 2,
      usage: "add-build-phase requires: <type> <name> --target <target> [--script <script>]"
    )

    let type = arguments.positional[0]
    let name = arguments.positional[1]

    // Get required target flag
    let targetName = try arguments.requireFlag(
      "--target", "-t",
      error: "add-build-phase requires --target or -t flag"
    )

    // Get optional script flag
    let script = arguments.getFlag("--script", "-s")

    // Validate target exists
    try validateTargets([targetName], in: utility)

    // Execute the command
    try utility.addBuildPhase(type: type, name: name, to: targetName, script: script)
  }

  static func printUsage() {
    print(
      """
      add-build-phase <type> <name> --target <target> [--script <script>]
        Add a build phase to a target
        
        Arguments:
          <type>                Type of build phase (script, copy-files, etc.)
          <name>                Name for the build phase
          --target, -t <target> Target to add the build phase to
          --script, -s <script> Optional script content for script build phases
        
        Examples:
          add-build-phase script "Run SwiftLint" --target MyApp --script "swiftlint"
          add-build-phase copy-files "Copy Resources" --target MyApp
          add-build-phase script "Post Build" -t MyApp -s "echo 'Build complete'"
        
        Notes:
          - Script is only applicable for script build phases
          - Build phase is added to the end of the target's build phases
          - Target must exist before adding build phase
      """)
  }
}

// MARK: - BaseCommand conformance
extension AddBuildPhaseCommand {

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
