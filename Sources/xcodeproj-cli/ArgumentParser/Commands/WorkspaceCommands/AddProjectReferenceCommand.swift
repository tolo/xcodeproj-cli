//
// AddProjectReferenceCommand.swift
// xcodeproj-cli
//
// ArgumentParser command for adding references to external projects
//

import ArgumentParser
import Foundation
@preconcurrency import PathKit

/// ArgumentParser command for adding project references
struct AddProjectReferenceCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "add-project-reference",
    abstract: "Add a reference to an external project"
  )

  @OptionGroup var global: GlobalOptions

  @Argument(help: "Path to the external project file")
  var projectPath: String

  @Option(help: "Group path where to add the reference")
  var group: String?

  @MainActor
  func run() async throws {
    // Validate path for security (path traversal protection)
    let validatedProjectPath = try SecurityUtils.validatePath(projectPath)

    let services = try ProjectServiceFactory.create(from: global)
    let crossProjectManager = CrossProjectManager(
      xcodeproj: services.utility.xcodeproj,
      projectPath: services.utility.projectPath
    )

    // Add project reference
    let fileRef = try crossProjectManager.addProjectReference(
      externalProjectPath: validatedProjectPath,
      groupPath: group
    )

    // Save changes
    try services.save()

    print("✅ Added reference to external project '\(projectPath)'")

    if global.verbose {
      print("  Referenced project: \(projectPath)")
      print("  File reference ID: \(fileRef.uuid)")
      if let groupPath = group {
        print("  Added to group: \(groupPath)")
      } else {
        print("  Added to root group")
      }
    }
  }
}
