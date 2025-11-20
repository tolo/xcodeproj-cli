//
// AddSchemeTargetCommand.swift
// xcodeproj-cli
//
// ArgumentParser command for adding targets to scheme build actions
//

import ArgumentParser
import Foundation
@preconcurrency import PathKit
import XcodeProj

/// ArgumentParser command for adding targets to schemes
struct AddSchemeTargetCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "add-scheme-target",
    abstract: "Add a target to a scheme's build action"
  )

  @OptionGroup var global: GlobalOptions

  @Argument(help: "Name of the scheme to modify")
  var schemeName: String

  @Argument(help: "Name of the target to add")
  var targetName: String

  @Option(
    help:
      "Comma-separated list of actions (build,test,run,profile,archive,analyze). Default: all actions",
    transform: { $0.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) } }
  )
  var action: [String]?

  @MainActor
  func run() async throws {
    let services = try ProjectServiceFactory.create(from: global)
    let schemeManager = SchemeManager(
      xcodeproj: services.utility.xcodeproj,
      projectPath: services.utility.projectPath
    )

    // Check if scheme exists
    let existingSchemes = try schemeManager.listSchemes(shared: true)
    if !existingSchemes.contains(schemeName) {
      throw ProjectError.schemeNotFound(schemeName)
    }

    // Parse build actions
    let buildActions = action ?? ["build", "test", "run", "profile", "archive", "analyze"]

    // Convert action strings to BuildFor enum values
    var buildFor: [XCScheme.BuildAction.Entry.BuildFor] = []
    for actionString in buildActions {
      switch actionString.lowercased() {
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
        print("⚠️  Unknown action '\(actionString)', skipping")
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

    // Save changes
    try services.save()

    print("✅ Added target '\(targetName)' to scheme '\(schemeName)'")

    if global.verbose {
      print("  Target: \(targetName)")
      print("  Actions: \(buildActions.joined(separator: ", "))")
    }
  }
}
