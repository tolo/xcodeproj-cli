//
// EnableTestCoverageCommand.swift
// xcodeproj-cli
//
// Command for enabling test coverage in schemes
//

import Foundation
@preconcurrency import PathKit
@preconcurrency import XcodeProj

struct EnableTestCoverageCommand: Command {
  static let commandName = "enable-test-coverage"
  static let description = "Enable test coverage for a scheme"

  static let category: CommandCategory = .schemes

  let schemeName: String
  let targets: [String]?
  let verbose: Bool

  init(arguments: ParsedArguments) throws {
    guard let name = arguments.positional.first else {
      throw ProjectError.invalidArguments("Scheme name is required")
    }

    self.schemeName = name

    // Parse target list if provided
    if let targetList = arguments.getFlag("--targets", "targets") {
      self.targets = targetList.split(separator: ",").map {
        String($0).trimmingCharacters(in: .whitespaces)
      }
    } else {
      self.targets = nil
    }

    self.verbose = arguments.boolFlags.contains("--verbose")
  }

  @MainActor
  func execute(with xcodeproj: XcodeProj, projectPath: Path) throws {
    let schemeManager = SchemeManager(xcodeproj: xcodeproj, projectPath: projectPath)

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

    if verbose {
      print("  Scheme: \(schemeName)")
      if let targetList = targets {
        print("  Coverage targets: \(targetList.joined(separator: ", "))")
      } else {
        print("  Coverage targets: All targets")
      }
    }
  }

  static func printUsage() {
    print(
      """
      Usage: enable-test-coverage <scheme> [options]

      Arguments:
        scheme            Name of the scheme to configure

      Options:
        --targets <list>  Comma-separated list of specific targets to collect coverage for
                         (default: all targets)
        --verbose         Show detailed output

      Examples:
        enable-test-coverage MyApp
        enable-test-coverage MyApp --targets MyApp,MyFramework
        enable-test-coverage Tests --targets Core,UI --verbose
      """)
  }

  static func execute(with arguments: ParsedArguments, utility: XcodeProjUtility) throws {
    let cmd = try EnableTestCoverageCommand(arguments: arguments)
    try cmd.execute(with: utility.xcodeproj, projectPath: utility.projectPath)
  }
}
