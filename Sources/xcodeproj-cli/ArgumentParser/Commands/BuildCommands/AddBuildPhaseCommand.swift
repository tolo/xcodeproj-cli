//
// AddBuildPhaseCommand.swift
// xcodeproj-cli
//

import ArgumentParser
import Foundation

/// ArgumentParser command for adding a build phase to a target
struct AddBuildPhaseCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "add-build-phase",
    abstract: "Add a build phase to a target",
    discussion: """
      Add a build phase (script, copy-files, etc.) to a target.

      Examples:
        xcodeproj-cli add-build-phase script "Run SwiftLint" --target MyApp --script "swiftlint"
        xcodeproj-cli add-build-phase copy-files "Copy Resources" --target MyApp
        xcodeproj-cli add-build-phase script "Post Build" -t MyApp -s "echo 'Build complete'"

      Notes:
        - Script is only applicable for script build phases
        - Build phase is added to the end of the target's build phases
        - Target must exist before adding build phase
      """
  )

  @OptionGroup var global: GlobalOptions

  @Argument(help: "Type of build phase (script, copy-files, etc.)")
  var type: String

  @Argument(help: "Name for the build phase")
  var name: String

  @Option(
    name: [.customLong("target"), .customShort("t")],
    help: "Target to add the build phase to"
  )
  var targetName: String

  @Option(
    name: [.customLong("script"), .customShort("s")],
    help: "Optional script content for script build phases"
  )
  var script: String?

  @MainActor
  func run() async throws {
    // Create project services
    let services = try ProjectServiceFactory.create(from: global)

    // Validate target exists
    let projectTargets = Set(services.utility.pbxproj.nativeTargets.map { $0.name })
    guard projectTargets.contains(targetName) else {
      throw ProjectError.targetNotFound(targetName)
    }

    // Execute the command
    try services.utility.addBuildPhase(type: type, name: name, to: targetName, script: script)

    // Save changes
    try services.save()

    if global.verbose {
      print("✅ Build phase '\(name)' (type: \(type)) added to target '\(targetName)'")
      if let scriptContent = script {
        print("   Script: \(scriptContent)")
      }
    }
  }
}
