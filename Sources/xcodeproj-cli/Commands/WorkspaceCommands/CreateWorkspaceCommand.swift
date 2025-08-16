//
// CreateWorkspaceCommand.swift
// xcodeproj-cli
//
// Command for creating Xcode workspaces
//

import Foundation
@preconcurrency import PathKit
@preconcurrency import XcodeProj

struct CreateWorkspaceCommand: Command {
  static let commandName = "create-workspace"
  static let description = "Create a new workspace"

  static let category: CommandCategory = .workspaces

  let workspaceName: String
  let verbose: Bool

  init(arguments: ParsedArguments) throws {
    guard let name = arguments.positional.first else {
      throw ProjectError.invalidArguments("Workspace name is required")
    }

    self.workspaceName = name
    self.verbose = arguments.boolFlags.contains("verbose")
  }

  @MainActor
  func execute(with xcodeproj: XcodeProj, projectPath: Path) throws {
    let workspaceManager = WorkspaceManager()

    // Create the workspace
    let workspace = try workspaceManager.createWorkspace(name: workspaceName)

    if verbose {
      print("  Location: \(FileManager.default.currentDirectoryPath)/\(workspaceName).xcworkspace")
      print("  Children count: \(workspace.data.children.count)")
    }
  }

  static func printUsage() {
    print(
      """
      Usage: create-workspace <name> [options]

      Arguments:
        name              Name of the workspace to create

      Options:
        --verbose         Show detailed output

      Examples:
        create-workspace MyWorkspace
        create-workspace MyApp --verbose
      """)
  }

  @MainActor
  static func execute(with arguments: ParsedArguments, utility: XcodeProjUtility) throws {
    let cmd = try CreateWorkspaceCommand(arguments: arguments)
    try cmd.execute(with: utility.xcodeproj, projectPath: utility.projectPath)
  }

  @MainActor
  static func executeAsWorkspaceCommand(with arguments: ParsedArguments, verbose: Bool) throws {
    let cmd = try CreateWorkspaceCommand(arguments: arguments)
    let workspaceManager = WorkspaceManager()

    // Create the workspace
    let workspace = try workspaceManager.createWorkspace(name: cmd.workspaceName)

    if cmd.verbose || verbose {
      print(
        "  Location: \(FileManager.default.currentDirectoryPath)/\(cmd.workspaceName).xcworkspace")
      print("  Children count: \(workspace.data.children.count)")
    }
  }
}
