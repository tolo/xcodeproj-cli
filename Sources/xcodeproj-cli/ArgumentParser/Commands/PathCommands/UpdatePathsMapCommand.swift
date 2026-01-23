//
// UpdatePathsMapCommand.swift
// xcodeproj-cli
//
// ArgumentParser command for updating file paths using a mapping of old to new paths
//

import ArgumentParser
import Foundation

/// ArgumentParser command for updating file paths using a mapping of old to new paths
struct UpdatePathsMapCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "update-paths-map",
    abstract: "Update file paths using a mapping of old to new paths"
  )

  @OptionGroup var global: GlobalOptions

  @Argument(
    parsing: .remaining,
    help:
      "Path mappings in format 'old:new' (e.g., 'Sources/Old/File.swift:Sources/New/File.swift')"
  )
  var mappings: [String]

  @MainActor
  func run() async throws {
    guard !mappings.isEmpty else {
      throw ProjectError.invalidArguments(
        "update-paths-map requires at least one path mapping in format 'old:new'"
      )
    }

    // Parse and validate path mappings from arguments
    var pathMappings: [String: String] = [:]
    for arg in mappings {
      let parts = arg.split(separator: ":")
      guard parts.count == 2 else {
        throw ProjectError.invalidArguments(
          "Invalid mapping format '\(arg)'. Expected 'old:new'"
        )
      }

      // Validate both paths for security
      let oldPath = String(parts[0])
      let newPath = String(parts[1])
      let validatedOldPath = try SecurityUtils.validatePath(oldPath)
      let validatedNewPath = try SecurityUtils.validatePath(newPath)

      pathMappings[validatedOldPath] = validatedNewPath
    }

    let services = try ProjectServiceFactory.create(from: global)
    services.utility.updateFilePaths(pathMappings)
    try services.save()
    print("✅ Updated \(pathMappings.count) file path mapping(s)")
  }
}
