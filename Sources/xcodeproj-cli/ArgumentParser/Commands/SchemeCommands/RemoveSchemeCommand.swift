//
// RemoveSchemeCommand.swift
// xcodeproj-cli
//
// ArgumentParser command for removing Xcode schemes
//

import ArgumentParser
import Foundation
@preconcurrency import PathKit

/// ArgumentParser command for removing schemes
struct RemoveSchemeCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "remove-scheme",
    abstract: "Remove a scheme"
  )

  @OptionGroup var global: GlobalOptions

  @Argument(help: "Name of the scheme to remove")
  var schemeName: String

  @MainActor
  func run() async throws {
    let services = try ProjectServiceFactory.create(from: global)
    let schemeManager = SchemeManager(
      xcodeproj: services.utility.xcodeproj,
      projectPath: services.utility.projectPath
    )

    // Check if scheme exists
    let existingSchemes = try schemeManager.listSchemes(shared: true)
    if !existingSchemes.contains(schemeName) {
      throw ProjectError.operationFailed("Scheme '\(schemeName)' not found")
    }

    // Remove the scheme
    try schemeManager.removeScheme(name: schemeName)

    // Save changes
    try services.save()

    print("✅ Removed scheme '\(schemeName)'")

    if global.verbose {
      print("  Removed: \(schemeName)")
    }
  }
}
