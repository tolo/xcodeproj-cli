//
// RemoveProjectFromWorkspaceCommand.swift
// xcodeproj-cli
//
// Command for removing projects from workspaces
//

import Foundation
@preconcurrency import PathKit
@preconcurrency import XcodeProj

struct RemoveProjectFromWorkspaceCommand: Command {
  static let commandName = "remove-project-from-workspace"
  static let description = "Remove a project from a workspace"

  static let category: CommandCategory = .workspaces

  let workspaceName: String
  let projectPath: String
  let verbose: Bool

  init(arguments: ParsedArguments) throws {
    guard arguments.positional.count >= 2 else {
      throw ProjectError.invalidArguments("Workspace name and project path are required")
    }

    self.workspaceName = arguments.positional[0]
    self.projectPath = arguments.positional[1]
    self.verbose = arguments.boolFlags.contains("verbose")
  }

  @MainActor
  func execute(with xcodeproj: XcodeProj, projectPath: Path) throws {
    let workspaceManager = WorkspaceManager()

    // Remove project from workspace
    try workspaceManager.removeProjectFromWorkspace(
      workspaceName: workspaceName,
      projectPath: self.projectPath
    )

    if verbose {
      print("  Workspace: \(workspaceName).xcworkspace")
      print("  Removed project: \(self.projectPath)")
    }
  }

  static func printUsage() {
    print(
      """
      Usage: remove-project-from-workspace <workspace-name> <project-path> [options]

      Arguments:
        workspace-name    Name of the workspace (without .xcworkspace extension)
        project-path      Path to the project to remove

      Options:
        --verbose         Show detailed output

      Examples:
        remove-project-from-workspace MyWorkspace App.xcodeproj
        remove-project-from-workspace MyWorkspace ../Framework/Framework.xcodeproj
      """)
  }

  @MainActor
  static func execute(with arguments: ParsedArguments, utility: XcodeProjUtility) throws {
    let cmd = try RemoveProjectFromWorkspaceCommand(arguments: arguments)
    try cmd.execute(with: utility.xcodeproj, projectPath: utility.projectPath)
  }

  @MainActor
  static func executeAsWorkspaceCommand(with arguments: ParsedArguments, verbose: Bool) throws {
    let cmd = try RemoveProjectFromWorkspaceCommand(arguments: arguments)
    let workspaceManager = WorkspaceManager()

    // Remove project from workspace
    try workspaceManager.removeProjectFromWorkspace(
      workspaceName: cmd.workspaceName,
      projectPath: cmd.projectPath
    )

    if cmd.verbose || verbose {
      print("  Workspace: \(cmd.workspaceName).xcworkspace")
      print("  Removed project: \(cmd.projectPath)")
    }
  }
}
