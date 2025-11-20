//
// CreateWorkspaceCommand.swift
// xcodeproj-cli
//
// ArgumentParser command for creating Xcode workspaces
//

import ArgumentParser
import Foundation

/// ArgumentParser command for creating workspaces
struct CreateWorkspaceCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "create-workspace",
    abstract: "Create a new workspace"
  )

  @OptionGroup var global: GlobalOptions

  @Argument(help: "Name of the workspace to create")
  var workspaceName: String

  @MainActor
  func run() async throws {
    let workspaceManager = WorkspaceManager(workspacePath: global.workspacePath)

    // Create the workspace
    let workspace = try workspaceManager.createWorkspace(name: workspaceName)

    if global.verbose {
      print("  Children count: \(workspace.data.children.count)")
    }
  }
}
