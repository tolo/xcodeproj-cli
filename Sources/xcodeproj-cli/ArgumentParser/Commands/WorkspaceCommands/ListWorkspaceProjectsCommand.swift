//
// ListWorkspaceProjectsCommand.swift
// xcodeproj-cli
//
// ArgumentParser command for listing projects in a workspace
//

import ArgumentParser
import Foundation

/// ArgumentParser command for listing workspace projects (READ-ONLY)
struct ListWorkspaceProjectsCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "list-workspace-projects",
    abstract: "List all projects in a workspace"
  )

  @OptionGroup var global: GlobalOptions

  @Argument(help: "Name of the workspace (without .xcworkspace extension)")
  var workspaceName: String

  @MainActor
  func run() async throws {
    let workspaceManager = WorkspaceManager(workspacePath: global.workspacePath)

    // List projects in workspace
    let projects = try workspaceManager.listWorkspaceProjects(workspaceName: workspaceName)

    if projects.isEmpty {
      print("No projects found in workspace '\(workspaceName)'")
    } else {
      print("📋 Projects in workspace '\(workspaceName)':")
      for (index, project) in projects.enumerated() {
        if global.verbose {
          print("  \(index + 1). \(project)")
        } else {
          print("  - \(project)")
        }
      }

      if global.verbose {
        print("\nTotal projects: \(projects.count)")
      }
    }
  }
}
