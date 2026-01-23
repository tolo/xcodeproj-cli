//
// AddSyncFolderCommand.swift
// xcodeproj-cli
//
// ArgumentParser command for adding a synchronized folder to the project
//

import ArgumentParser
import Foundation

/// ArgumentParser command for adding a synchronized folder that maintains sync with filesystem
struct AddSyncFolderCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "add-sync-folder",
    abstract: "Add a synchronized folder that maintains sync with filesystem"
  )

  @OptionGroup var global: GlobalOptions

  @Argument(help: "Path to the folder to add")
  var folderPath: String

  @Option(
    name: [.customLong("group"), .customShort("g")],
    help: "Group to add the folder to")
  var groupPath: String

  @Option(
    name: [.customLong("targets"), .customShort("t")],
    parsing: .upToNextOption,
    help: "Target names to add folder to")
  var targets: [String]

  @MainActor
  func run() async throws {
    // Validate paths for security (path traversal protection)
    let validatedFolderPath = try SecurityUtils.validatePath(folderPath)
    let validatedGroupPath = try SecurityUtils.validatePath(groupPath)

    let services = try ProjectServiceFactory.create(from: global)
    try services.utility.addSynchronizedFolder(
      folderPath: validatedFolderPath,
      to: validatedGroupPath,
      targets: targets
    )
    try services.save()
    print("✅ Synchronized folder '\(validatedFolderPath)' added to group '\(validatedGroupPath)'")
    print("Note: Folder will be synchronized with filesystem changes")
  }
}
