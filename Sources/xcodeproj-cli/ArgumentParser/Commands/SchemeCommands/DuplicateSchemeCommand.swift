//
// DuplicateSchemeCommand.swift
// xcodeproj-cli
//
// ArgumentParser command for duplicating Xcode schemes
//

import ArgumentParser
import Foundation
@preconcurrency import PathKit

/// ArgumentParser command for duplicating schemes
struct DuplicateSchemeCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "duplicate-scheme",
    abstract: "Duplicate an existing scheme"
  )

  @OptionGroup var global: GlobalOptions

  @Argument(help: "Name of the scheme to duplicate")
  var sourceName: String

  @Argument(help: "Name for the new scheme")
  var destinationName: String

  @MainActor
  func run() async throws {
    let services = try ProjectServiceFactory.create(from: global)
    let schemeManager = SchemeManager(
      xcodeproj: services.utility.xcodeproj,
      projectPath: services.utility.projectPath
    )

    // Check if source scheme exists
    let existingSchemes = try schemeManager.listSchemes(shared: true)
    if !existingSchemes.contains(sourceName) {
      throw ProjectError.schemeNotFound(sourceName)
    }

    // Check if destination scheme already exists
    if existingSchemes.contains(destinationName) {
      throw ProjectError.operationFailed("Destination scheme '\(destinationName)' already exists")
    }

    // Duplicate the scheme
    _ = try schemeManager.duplicateScheme(
      sourceName: sourceName,
      destinationName: destinationName
    )

    // Save changes
    try services.save()

    print("✅ Duplicated scheme '\(sourceName)' to '\(destinationName)'")

    if global.verbose {
      print("  Source: \(sourceName)")
      print("  Destination: \(destinationName)")
    }
  }
}
