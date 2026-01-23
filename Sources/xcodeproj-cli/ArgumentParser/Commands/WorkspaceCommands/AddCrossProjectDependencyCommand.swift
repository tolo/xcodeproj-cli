//
// AddCrossProjectDependencyCommand.swift
// xcodeproj-cli
//
// ArgumentParser command for adding cross-project dependencies
//

import ArgumentParser
import Foundation
@preconcurrency import PathKit

/// ArgumentParser command for adding cross-project dependencies
struct AddCrossProjectDependencyCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "add-cross-project-dependency",
    abstract: "Add a dependency on a target in another project"
  )

  @OptionGroup var global: GlobalOptions

  @Argument(help: "Name of the target to add dependency to")
  var targetName: String

  @Argument(help: "Path to the external project")
  var externalProject: String

  @Argument(help: "Name of the target in the external project")
  var externalTarget: String

  @Option(help: "Specific GUID of the external target (optional)")
  var targetId: String?

  @MainActor
  func run() async throws {
    let services = try ProjectServiceFactory.create(from: global)
    let crossProjectManager = CrossProjectManager(
      xcodeproj: services.utility.xcodeproj,
      projectPath: services.utility.projectPath
    )

    // Validate external project path for security
    let validatedExternalProject = try SecurityUtils.validatePath(externalProject)

    // Add cross-project dependency
    try crossProjectManager.addCrossProjectDependency(
      targetName: targetName,
      externalProjectPath: validatedExternalProject,
      externalTargetName: externalTarget,
      externalTargetGUID: targetId
    )

    // Save changes
    try services.save()

    print(
      "✅ Added cross-project dependency from '\(targetName)' to '\(externalTarget)' in '\(externalProject)'"
    )

    if global.verbose {
      print("  Target: \(targetName)")
      print("  External project: \(externalProject)")
      print("  External target: \(externalTarget)")
      if let guid = targetId {
        print("  External target GUID: \(guid)")
      }
    }
  }
}
