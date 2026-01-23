//
// CreateSchemeCommand.swift
// xcodeproj-cli
//
// ArgumentParser command for creating Xcode schemes
//

import ArgumentParser
import Foundation
@preconcurrency import PathKit

/// ArgumentParser command for creating schemes
struct CreateSchemeCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "create-scheme",
    abstract: "Create a new scheme for a target"
  )

  @OptionGroup var global: GlobalOptions

  @Argument(help: "Name of the scheme to create")
  var schemeName: String

  @Option(help: "Target to create scheme for (default: scheme name)")
  var target: String?

  @Flag(help: "Create as shared scheme (default)")
  var shared: Bool = false

  @Flag(help: "Create as user-specific scheme")
  var user: Bool = false

  @MainActor
  func run() async throws {
    let services = try ProjectServiceFactory.create(from: global)
    let schemeManager = SchemeManager(
      xcodeproj: services.utility.xcodeproj,
      projectPath: services.utility.projectPath
    )

    let targetName = target ?? schemeName
    let isShared = shared || !user

    // Check if scheme already exists
    let existingSchemes = try schemeManager.listSchemes(shared: isShared)
    if existingSchemes.contains(schemeName) {
      throw ProjectError.operationFailed("Scheme '\(schemeName)' already exists")
    }

    // Create the scheme
    _ = try schemeManager.createScheme(
      name: schemeName,
      targetName: targetName,
      shared: isShared
    )

    // Save changes
    try services.save()

    print("✅ Created scheme '\(schemeName)' for target '\(targetName)'")

    if global.verbose {
      print("  Location: \(isShared ? "Shared" : "User")")
      print("  Target: \(targetName)")
    }
  }
}
