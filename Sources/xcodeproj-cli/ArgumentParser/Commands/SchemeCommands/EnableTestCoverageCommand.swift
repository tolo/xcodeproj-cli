//
// EnableTestCoverageCommand.swift
// xcodeproj-cli
//
// ArgumentParser command for enabling test coverage in schemes
//

import ArgumentParser
import Foundation
@preconcurrency import PathKit

/// ArgumentParser command for enabling test coverage
struct EnableTestCoverageCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "enable-test-coverage",
    abstract: "Enable test coverage for a scheme"
  )

  @OptionGroup var global: GlobalOptions

  @Argument(help: "Name of the scheme to configure")
  var schemeName: String

  @Option(
    help: "Comma-separated list of specific targets to collect coverage for (default: all targets)",
    transform: { $0.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) } }
  )
  var targets: [String]?

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

    // Enable test coverage
    try schemeManager.enableTestCoverage(
      schemeName: schemeName,
      targets: targets
    )

    // Save changes
    try services.save()

    print("✅ Enabled test coverage for scheme '\(schemeName)'")

    if global.verbose {
      print("  Scheme: \(schemeName)")
      if let targetList = targets {
        print("  Coverage targets: \(targetList.joined(separator: ", "))")
      } else {
        print("  Coverage targets: All targets")
      }
    }
  }
}
