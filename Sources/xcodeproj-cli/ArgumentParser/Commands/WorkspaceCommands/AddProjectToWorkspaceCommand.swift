//
// AddProjectToWorkspaceCommand.swift
// xcodeproj-cli
//
// ArgumentParser command for adding projects to workspaces
//

import ArgumentParser
import Foundation

/// ArgumentParser command for adding projects to workspaces
struct AddProjectToWorkspaceCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "add-project-to-workspace",
    abstract: "Add a project to an existing workspace"
  )

  @OptionGroup var global: GlobalOptions

  @Argument(help: "Name of the workspace (without .xcworkspace extension)")
  var workspaceName: String

  @Argument(help: "Path to the project to add")
  var projectPath: String

  @MainActor
  func run() async throws {
    let workspaceManager = WorkspaceManager(workspacePath: global.workspacePath)

    // Add project to workspace
    try workspaceManager.addProjectToWorkspace(
      workspaceName: workspaceName,
      projectPath: projectPath
    )

    if global.verbose {
      print("  Workspace: \(workspaceName).xcworkspace")
      print("  Added project: \(projectPath)")
    }
  }
}
