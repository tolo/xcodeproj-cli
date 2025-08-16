//
// Command.swift
// xcodeproj-cli
//
// Base command protocol and abstract base class for command implementations
//

import Foundation
@preconcurrency import XcodeProj

/// Categories for organizing commands in help output
enum CommandCategory: String, CaseIterable {
  case fileOperations = "File & Folder Operations"
  case targetManagement = "Target Management"
  case groupOperations = "Group Operations"
  case buildConfiguration = "Build Configuration"
  case frameworks = "Frameworks & Dependencies"
  case swiftPackages = "Swift Packages"
  case inspection = "Project Inspection & Validation"
  case pathOperations = "Path Operations"
  case schemes = "Schemes"
  case workspaces = "Workspaces"
  case crossProject = "Cross-Project"

  var displayOrder: Int {
    switch self {
    case .fileOperations: return 1
    case .targetManagement: return 2
    case .groupOperations: return 3
    case .buildConfiguration: return 4
    case .frameworks: return 5
    case .swiftPackages: return 6
    case .inspection: return 7
    case .pathOperations: return 8
    case .schemes: return 9
    case .workspaces: return 10
    case .crossProject: return 11
    }
  }
}

/// Protocol for command implementations
protocol Command {
  /// The name of the command as used on the command line
  static var commandName: String { get }

  /// Brief description of what the command does
  static var description: String { get }

  /// Category for organizing commands in help output
  static var category: CommandCategory { get }

  /// Indicates if this is a read-only command that doesn't modify the project
  static var isReadOnly: Bool { get }

  /// Execute the command with parsed arguments and utility
  @MainActor
  static func execute(with arguments: ParsedArguments, utility: XcodeProjUtility) throws

  /// Print usage information for this specific command
  static func printUsage()
}

// Default implementation for isReadOnly (most commands modify the project)
extension Command {
  static var isReadOnly: Bool { false }
}

/// Abstract base class providing common functionality for commands
class BaseCommand {

  /// Validate that required positional arguments are provided
  static func requirePositionalArguments(_ arguments: ParsedArguments, count: Int, usage: String)
    throws
  {
    guard arguments.positional.count >= count else {
      let missingCount = count - arguments.positional.count
      let errorMessage =
        missingCount == 1
        ? "Missing required argument. \(usage)"
        : "Missing \(missingCount) required arguments. \(usage)"
      throw ProjectError.invalidArguments(errorMessage)
    }
  }

  /// Parse comma-separated target list from string
  static func parseTargets(from targetsString: String) -> [String] {
    return targetsString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
  }

  /// Get targets from arguments, supporting both --target and --targets flags
  /// Accepts both singular --target and plural --targets for consistency
  static func getTargets(from arguments: ParsedArguments, requireFlag: Bool = true) throws
    -> [String]?
  {
    // Check for --targets (plural) first
    if let targetsStr = arguments.getFlag("--targets", "-t") {
      return parseTargets(from: targetsStr)
    }

    // Fall back to --target (singular) for consistency
    if let targetStr = arguments.getFlag("--target") {
      return parseTargets(from: targetStr)
    }

    if requireFlag {
      throw ProjectError.invalidArguments("Missing required --targets or --target flag")
    }

    return nil
  }

  /// Validate that targets exist in the project
  @MainActor
  static func validateTargets(_ targetNames: [String], in utility: XcodeProjUtility) throws {
    let projectTargets = Set(utility.pbxproj.nativeTargets.map { $0.name })

    for targetName in targetNames {
      guard projectTargets.contains(targetName) else {
        throw ProjectError.targetNotFound(targetName)
      }
    }
  }

  /// Validate that a group exists in the project
  @MainActor
  static func validateGroup(_ groupPath: String, in utility: XcodeProjUtility) throws {
    guard XcodeProjectHelpers.findGroup(named: groupPath, in: utility.pbxproj.groups) != nil else {
      throw ProjectError.groupNotFound(groupPath)
    }
  }

  /// Validate that a product type is supported
  static func validateProductType(_ productType: String) throws {
    let validProductTypes = [
      "app",
      "application",
      "com.apple.product-type.application",
      "framework",
      "com.apple.product-type.framework",
      "static-library",
      "com.apple.product-type.library.static",
      "dynamic-library",
      "com.apple.product-type.library.dynamic",
      "test",
      "com.apple.product-type.bundle.unit-test",
      "ui-test",
      "com.apple.product-type.bundle.ui-testing",
      "bundle",
      "com.apple.product-type.bundle",
      "tool",
      "com.apple.product-type.tool",
    ]

    guard validProductTypes.contains(productType) else {
      throw ProjectError.invalidArguments(
        "Invalid product type '\(productType)'. Valid types: \(validProductTypes.joined(separator: ", "))"
      )
    }
  }
}
