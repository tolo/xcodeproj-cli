//
// AddFileCommand.swift
// xcodeproj-cli
//
// ArgumentParser command for adding a single file to the project
//

import ArgumentParser
import Foundation

/// ArgumentParser command for adding a single file to specified group and targets
struct AddFileCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "add-file",
    abstract: "Add a single file to specified group and targets",
    discussion: """
      Adds a single file to the Xcode project in the specified group and targets.

      The --group parameter accepts either:
      • Simple group name: "Models"
      • Hierarchical path: "App/Source/Models"

      Hierarchical paths are resolved to find the exact group. If path resolution
      fails, the tool attempts to find a group with the last component name.

      Examples:
        # Using simple group name
        xcodeproj-cli add-file MyFile.swift --group Models --targets MyApp

        # Using hierarchical path (NEW)
        xcodeproj-cli add-file MyFile.swift --group App/Source/Models --targets MyApp

        # Real-world examples
        xcodeproj-cli add-file AppDelegate.swift \\
          --group MyApp/Source/Application \\
          --targets MyApp

        xcodeproj-cli add-file LoginView.swift \\
          --group Features/Authentication/Views \\
          --targets MyApp

      To discover groups:
        xcodeproj-cli list-groups --show-names
      """
  )

  @OptionGroup var global: GlobalOptions

  @Argument(help: "Path to the file to add")
  var filePath: String

  @Option(
    name: [.customLong("group"), .customShort("g")],
    help: "Group to add the file to")
  var groupPath: String

  @Option(
    name: [.customLong("targets"), .customShort("t")],
    parsing: .upToNextOption,
    help: "Target names to add file to")
  var targets: [String]

  @MainActor
  func run() async throws {
    // Validate path for security (path traversal protection)
    let validatedPath = try SecurityUtils.validatePath(filePath)
    let validatedGroup = try SecurityUtils.validatePath(groupPath)

    let services = try ProjectServiceFactory.create(from: global)
    try services.utility.addFile(
      path: validatedPath,
      to: validatedGroup,
      targets: targets
    )
    try services.save()
    print("✅ File '\(validatedPath)' added to group '\(validatedGroup)'")
  }
}
