//
// MoveFileCommand.swift
// xcodeproj-cli
//
// ArgumentParser command for moving/renaming a file in the project
//

import ArgumentParser
import Foundation

/// ArgumentParser command for moving or renaming a file in the project
struct MoveFileCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "move-file",
    abstract: "Move or rename a file in the project"
  )

  @OptionGroup var global: GlobalOptions

  @Argument(help: "Current path or name of the file")
  var filePath: String

  @Argument(help: "New path or name for the file (optional if using --to-group)")
  var newPath: String?

  @Option(
    name: .customLong("to-group"),
    help: "Move file to a different group")
  var toGroup: String?

  @MainActor
  func run() async throws {
    // Validate paths for security (path traversal protection)
    let validatedFilePath = try SecurityUtils.validatePath(filePath)
    let validatedNewPath = try newPath.map { try SecurityUtils.validatePath($0) }
    let validatedToGroup = try toGroup.map { try SecurityUtils.validatePath($0) }

    let services = try ProjectServiceFactory.create(from: global)

    if let targetGroup = validatedToGroup {
      // Move file to a different group
      try services.utility.moveFileToGroup(filePath: validatedFilePath, targetGroup: targetGroup)
      try services.save()
      print("✅ File '\(validatedFilePath)' moved to group '\(targetGroup)'")
    } else if let newPath = validatedNewPath {
      // Traditional move/rename with new path
      try services.utility.moveFile(from: validatedFilePath, to: newPath)
      try services.save()
      print("✅ File moved from '\(validatedFilePath)' to '\(newPath)'")
    } else {
      throw ValidationError(
        "move-file requires either --to-group <group> or <new-path> argument")
    }

    print(
      "Note: This updates the file reference in the project. If the file needs to be moved on disk, you should do that separately."
    )
  }
}
