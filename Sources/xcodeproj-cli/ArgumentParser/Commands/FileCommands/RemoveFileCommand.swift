//
// RemoveFileCommand.swift
// xcodeproj-cli
//
// ArgumentParser command for removing a file from the project
//

import ArgumentParser
import Foundation

/// ArgumentParser command for removing a file from the project
struct RemoveFileCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "remove-file",
    abstract: "Remove a file from the project"
  )

  @OptionGroup var global: GlobalOptions

  @Argument(help: "Path or name of the file to remove from the project")
  var filePath: String

  @MainActor
  func run() async throws {
    // Validate path for security (path traversal protection)
    let validatedFilePath = try SecurityUtils.validatePath(filePath)

    let services = try ProjectServiceFactory.create(from: global)
    try services.utility.removeFile(validatedFilePath)
    try services.save()
    print("✅ File '\(validatedFilePath)' removed from project")
    print("Note: This only removes the file reference from the project, not from the filesystem.")
  }
}
