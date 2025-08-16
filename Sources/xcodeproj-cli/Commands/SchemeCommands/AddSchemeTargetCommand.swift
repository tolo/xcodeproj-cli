//
// AddSchemeTargetCommand.swift
// xcodeproj-cli
//
// Command for adding targets to scheme build actions
//

import Foundation
@preconcurrency import PathKit
@preconcurrency import XcodeProj

struct AddSchemeTargetCommand: Command {
  static let commandName = "add-scheme-target"
  static let description = "Add a target to a scheme's build action"

  static let category: CommandCategory = .schemes

  let schemeName: String
  let targetName: String
  let buildActions: [String]
  let verbose: Bool

  init(arguments: ParsedArguments) throws {
    guard arguments.positional.count >= 2 else {
      throw ProjectError.invalidArguments("Scheme name and target name are required")
    }

    self.schemeName = arguments.positional[0]
    self.targetName = arguments.positional[1]

    // Parse build actions
    if let action = arguments.getFlag("--action", "action") {
      self.buildActions = action.split(separator: ",").map {
        String($0).trimmingCharacters(in: .whitespaces)
      }
    } else {
      // Default to all actions
      self.buildActions = ["build", "test", "run", "profile", "archive", "analyze"]
    }

    self.verbose = arguments.boolFlags.contains("--verbose")
  }

  @MainActor
  func execute(with xcodeproj: XcodeProj, projectPath: Path) throws {
    let schemeManager = SchemeManager(xcodeproj: xcodeproj, projectPath: projectPath)

    // Check if scheme exists
    let existingSchemes = try schemeManager.listSchemes(shared: true)
    if !existingSchemes.contains(schemeName) {
      throw ProjectError.schemeNotFound(schemeName)
    }

    // Convert action strings to BuildFor enum values
    var buildFor: [XCScheme.BuildAction.Entry.BuildFor] = []
    for action in buildActions {
      switch action.lowercased() {
      case "build", "running", "run":
        buildFor.append(.running)
      case "test", "testing":
        buildFor.append(.testing)
      case "profile", "profiling":
        buildFor.append(.profiling)
      case "archive", "archiving":
        buildFor.append(.archiving)
      case "analyze", "analyzing":
        buildFor.append(.analyzing)
      default:
        print("⚠️  Unknown action '\(action)', skipping")
      }
    }

    if buildFor.isEmpty {
      throw ProjectError.invalidArguments("No valid build actions specified")
    }

    // Add target to scheme
    try schemeManager.addTargetToScheme(
      schemeName: schemeName,
      targetName: targetName,
      buildFor: buildFor
    )

    if verbose {
      print("  Target: \(targetName)")
      print("  Actions: \(buildActions.joined(separator: ", "))")
    }
  }

  static func execute(with arguments: ParsedArguments, utility: XcodeProjUtility) throws {
    let cmd = try AddSchemeTargetCommand(arguments: arguments)
    try cmd.execute(with: utility.xcodeproj, projectPath: utility.projectPath)
  }

  static func printUsage() {
    print(
      """
      Usage: add-scheme-target <scheme> <target> [options]

      Arguments:
        scheme            Name of the scheme to modify
        target            Name of the target to add

      Options:
        --action <actions>  Comma-separated list of actions (build,test,run,profile,archive,analyze)
                           Default: all actions
        --verbose          Show detailed output

      Examples:
        add-scheme-target MyApp MyFramework
        add-scheme-target MyApp Tests --action test
        add-scheme-target Production Analytics --action build,run,archive
      """)
  }
}
