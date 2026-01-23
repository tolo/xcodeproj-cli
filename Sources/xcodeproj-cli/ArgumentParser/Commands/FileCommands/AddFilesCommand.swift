//
// AddFilesCommand.swift
// xcodeproj-cli
//
// ArgumentParser command for adding multiple files to the project in batch
//

import ArgumentParser
import Foundation

/// ArgumentParser command for adding multiple files to specified groups and targets in batch
struct AddFilesCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "add-files",
    abstract: "Add multiple files to specified groups and targets in batch"
  )

  @OptionGroup var global: GlobalOptions

  @Argument(
    help:
      "File paths to add (use file:group format for per-file groups, or use --group for all files)"
  )
  var filePaths: [String]

  @Option(
    name: [.customLong("group"), .customShort("g")],
    help: "Group to add all files to (not used with file:group format)")
  var groupPath: String?

  @Option(
    name: [.customLong("targets"), .customShort("t")],
    parsing: .upToNextOption,
    help: "Target names to add files to")
  var targets: [String]

  @MainActor
  func run() async throws {
    guard !filePaths.isEmpty else {
      throw ValidationError("add-files requires at least one file path")
    }

    // Validate paths for security (path traversal protection)
    // Check if we have file:group pairs or files with shared group
    var files: [(path: String, group: String)] = []

    // Check if any arguments contain colons (file:group format)
    let hasColonFormat = filePaths.contains { $0.contains(":") }

    if hasColonFormat {
      // Parse file:group pairs format
      for arg in filePaths {
        let parts = arg.split(separator: ":")
        if parts.count == 2 {
          let validatedPath = try SecurityUtils.validatePath(String(parts[0]))
          let validatedGroup = try SecurityUtils.validatePath(String(parts[1]))
          files.append((validatedPath, validatedGroup))
        } else {
          throw ValidationError(
            "Invalid file:group format: '\(arg)'. Use 'file:group' or provide --group flag for all files."
          )
        }
      }
    } else {
      // Multiple files with shared group format
      guard let group = groupPath else {
        throw ValidationError(
          "add-files requires --group or -g flag when not using file:group format")
      }

      let validatedGroup = try SecurityUtils.validatePath(group)

      // Create file:group pairs for all files
      for filePath in filePaths {
        let validatedPath = try SecurityUtils.validatePath(filePath)
        files.append((validatedPath, validatedGroup))
      }
    }

    let services = try ProjectServiceFactory.create(from: global)

    // Execute the command
    try services.utility.addFiles(files, to: targets)
    try services.save()
    print("✅ \(files.count) file(s) added to project")
  }
}
