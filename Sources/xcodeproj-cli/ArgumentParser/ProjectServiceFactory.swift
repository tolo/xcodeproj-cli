//
// ProjectServiceFactory.swift
// xcodeproj-cli
//

import Foundation
@preconcurrency import PathKit
@preconcurrency import XcodeProj

/// Container holding project manipulation utility with dry-run support
@MainActor
final class ProjectServices {
  let utility: XcodeProjUtility
  private let dryRun: Bool

  init(utility: XcodeProjUtility, dryRun: Bool) {
    self.utility = utility
    self.dryRun = dryRun
  }

  /// Save all changes to disk
  func save() throws {
    guard !dryRun else {
      print("[DRY RUN] Would save changes to project")
      return
    }
    try utility.commitTransaction()
  }

  /// Rollback all changes
  func rollback() throws {
    try utility.rollbackTransaction()
  }
}

/// Factory for creating ProjectServices from global options
@MainActor
final class ProjectServiceFactory {
  static func create(
    projectPath: String? = nil,
    verbose: Bool = false,
    dryRun: Bool = false,
    readOnly: Bool = false
  ) throws -> ProjectServices {
    // Determine project path (auto-detect if nil)
    let resolvedPath: String
    if let projectPath = projectPath {
      resolvedPath = projectPath
    } else {
      let fileManager = FileManager.default
      let currentPath = fileManager.currentDirectoryPath
      let projects = try fileManager.contentsOfDirectory(atPath: currentPath)
        .filter { $0.hasSuffix(".xcodeproj") }

      guard let firstProject = projects.first else {
        print("Error: No .xcodeproj found in current directory")
        print("Specify project with --project option")
        throw ProjectError.invalidArguments("No project file specified")
      }

      if projects.count > 1 {
        print("Warning: Multiple .xcodeproj files found, using: \(firstProject)")
      }
      resolvedPath = firstProject
    }

    // Initialize utility (validates project exists and sets up all services)
    let utility = try XcodeProjUtility(path: resolvedPath, verbose: verbose)

    // Begin transaction for change tracking (skip for read-only commands)
    if !readOnly {
      try utility.beginTransaction()
    }

    return ProjectServices(utility: utility, dryRun: dryRun)
  }

  static func create(from options: GlobalOptions, readOnly: Bool = false) throws -> ProjectServices {
    return try create(
      projectPath: options.projectPath,
      verbose: options.verbose,
      dryRun: options.dryRun,
      readOnly: readOnly
    )
  }
}
