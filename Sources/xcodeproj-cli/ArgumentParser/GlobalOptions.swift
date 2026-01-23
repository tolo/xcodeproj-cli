//
// GlobalOptions.swift
// xcodeproj-cli
//

import ArgumentParser
import Foundation
@preconcurrency import XcodeProj

/// Shared global options available to all commands
struct GlobalOptions: ParsableArguments {
  @Option(
    name: [.customLong("project"), .customShort("p")],
    help: "Path to .xcodeproj file (default: looks for *.xcodeproj in current directory)")
  var projectPath: String?

  @Option(
    name: [.customLong("workspace"), .customShort("w")],
    help: "Path to .xcworkspace file")
  var workspacePath: String?

  @Flag(
    name: [.customLong("verbose"), .customShort("V")],
    help: "Enable verbose output with performance metrics")
  var verbose = false

  @Flag(
    name: [.customLong("dry-run")],
    help: "Preview changes without saving")
  var dryRun = false
}

// MARK: - Validation Helpers

/// Extension providing common validation helpers for commands
@MainActor
extension GlobalOptions {
  /// Validate that a target exists in the project
  /// - Parameters:
  ///   - targetName: Name of the target to validate
  ///   - utility: Project utility to check against
  /// - Throws: ProjectError.targetNotFound if target doesn't exist
  func validateTarget(_ targetName: String, in utility: XcodeProjUtility) throws {
    let projectTargets = Set(utility.pbxproj.nativeTargets.map { $0.name })
    guard projectTargets.contains(targetName) else {
      throw ProjectError.targetNotFound(targetName)
    }
  }

  /// Validate that multiple targets exist in the project
  /// - Parameters:
  ///   - targetNames: Names of the targets to validate
  ///   - utility: Project utility to check against
  /// - Throws: ProjectError.targetNotFound for the first missing target
  func validateTargets(_ targetNames: [String], in utility: XcodeProjUtility) throws {
    let projectTargets = Set(utility.pbxproj.nativeTargets.map { $0.name })
    for targetName in targetNames {
      guard projectTargets.contains(targetName) else {
        throw ProjectError.targetNotFound(targetName)
      }
    }
  }

  /// Validate that a build configuration exists in the project
  /// - Parameters:
  ///   - configName: Name of the configuration to validate
  ///   - utility: Project utility to check against
  /// - Throws: ProjectError.configurationNotFound if configuration doesn't exist
  func validateConfiguration(_ configName: String, in utility: XcodeProjUtility) throws {
    guard let configList = utility.pbxproj.rootObject?.buildConfigurationList else {
      throw ProjectError.invalidArguments("No build configurations found in project")
    }

    let configs = configList.buildConfigurations
    let configNames = Set(configs.compactMap { $0.name })
    guard configNames.contains(configName) else {
      throw ProjectError.configurationNotFound(configName)
    }
  }
}
