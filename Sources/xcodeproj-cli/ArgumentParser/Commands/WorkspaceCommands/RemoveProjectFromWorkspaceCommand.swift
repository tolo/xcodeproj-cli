//
// RemoveProjectFromWorkspaceCommand.swift
// xcodeproj-cli
//
// ArgumentParser command for removing projects from workspaces
//

import ArgumentParser
import Foundation

/// ArgumentParser command for removing projects from workspaces
struct RemoveProjectFromWorkspaceCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "remove-project-from-workspace",
    abstract: "Remove a project from a workspace"
  )

  @OptionGroup var global: GlobalOptions

  @Argument(help: "Name of the workspace (without .xcworkspace extension)")
  var workspaceName: String

  @Argument(help: "Path to the project to remove")
  var projectPath: String

  @MainActor
  func run() async throws {
    let workspaceManager = WorkspaceManager(workspacePath: global.workspacePath)

    // Remove project from workspace
    try workspaceManager.removeProjectFromWorkspace(
      workspaceName: workspaceName,
      projectPath: projectPath
    )

    if global.verbose {
      print("  Workspace: \(workspaceName).xcworkspace")
      print("  Removed project: \(projectPath)")
    }
  }
}
