//
// AddFolderCommand.swift
// xcodeproj-cli
//
// ArgumentParser command for adding files from a filesystem folder to the project
//

import ArgumentParser
import Foundation

/// ArgumentParser command for adding files from a filesystem folder to project group
struct AddFolderCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "add-folder",
    abstract: "Add files from filesystem folder to project group"
  )

  @OptionGroup var global: GlobalOptions

  @Argument(help: "Path to the folder containing files to add")
  var folderPath: String

  @Option(
    name: [.customLong("group"), .customShort("g")],
    help: "Group to add the files to")
  var groupPath: String

  @Option(
    name: [.customLong("targets"), .customShort("t")],
    parsing: .upToNextOption,
    help: "Target names to add files to")
  var targets: [String]

  @Flag(
    name: [.customLong("recursive"), .customShort("r")],
    help: "Include files from subdirectories")
  var recursive = false

  @Flag(
    name: .customLong("create-groups"),
    help: "Create group hierarchy matching folder structure (default behavior)")
  var createGroups = false

  @Flag(
    name: .customLong("no-create-groups"),
    help: "Don't create group hierarchy")
  var noCreateGroups = false

  @MainActor
  func run() async throws {
    // Validate paths for security (path traversal protection)
    let validatedFolderPath = try SecurityUtils.validatePath(folderPath)
    let validatedGroupPath = try SecurityUtils.validatePath(groupPath)

    // Determine createGroups behavior:
    // - If --create-groups is specified, create groups (for backward compatibility)
    // - If --no-create-groups is specified, don't create groups
    // - Default (neither flag): create groups (new default behavior)
    let shouldCreateGroups: Bool
    if createGroups && noCreateGroups {
      // Both flags specified - error
      throw ProjectError.invalidArguments(
        "Cannot specify both --create-groups and --no-create-groups")
    } else if noCreateGroups {
      shouldCreateGroups = false
    } else {
      // Default to true (create groups), whether --create-groups is explicitly set or not
      shouldCreateGroups = true
    }

    let services = try ProjectServiceFactory.create(from: global)
    try services.utility.addFolder(
      path: validatedFolderPath,
      to: validatedGroupPath,
      targets: targets,
      recursive: recursive,
      createGroups: shouldCreateGroups
    )
    try services.save()
    print(
      "✅ Files from '\(validatedFolderPath)' added to group '\(validatedGroupPath)'\(recursive ? " (recursive)" : "")"
    )
  }
}
