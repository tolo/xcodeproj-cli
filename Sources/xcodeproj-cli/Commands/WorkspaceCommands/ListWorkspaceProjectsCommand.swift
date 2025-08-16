//
// ListWorkspaceProjectsCommand.swift
// xcodeproj-cli
//
// Command for listing projects in a workspace
//

import Foundation
@preconcurrency import PathKit
@preconcurrency import XcodeProj

struct ListWorkspaceProjectsCommand: Command {
  static let commandName = "list-workspace-projects"
  static let description = "List all projects in a workspace"

  static let category: CommandCategory = .workspaces

  static let isReadOnly = true
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

    // List projects in workspace
    let projects = try workspaceManager.listWorkspaceProjects(workspaceName: workspaceName)

    if projects.isEmpty {
      print("No projects found in workspace '\(workspaceName)'")
    } else {
      print("Projects in workspace '\(workspaceName)':")
      for (index, project) in projects.enumerated() {
        if verbose {
          print("  \(index + 1). \(project)")
        } else {
          print("  \(project)")
        }
      }

      if verbose {
        print("\nTotal projects: \(projects.count)")
      }
    }
  }

  static func printUsage() {
    print(
      """
      Usage: list-workspace-projects <workspace-name> [options]

      Arguments:
        workspace-name    Name of the workspace (without .xcworkspace extension)

      Options:
        --verbose         Show detailed output with numbering and count

      Examples:
        list-workspace-projects MyWorkspace
        list-workspace-projects MyWorkspace --verbose
      """)
  }

  @MainActor
  static func execute(with arguments: ParsedArguments, utility: XcodeProjUtility) throws {
    let cmd = try ListWorkspaceProjectsCommand(arguments: arguments)
    try cmd.execute(with: utility.xcodeproj, projectPath: utility.projectPath)
  }

  @MainActor
  static func executeAsWorkspaceCommand(with arguments: ParsedArguments, verbose: Bool) throws {
    let cmd = try ListWorkspaceProjectsCommand(arguments: arguments)
    let workspaceManager = WorkspaceManager()

    // List projects in workspace
    let projects = try workspaceManager.listWorkspaceProjects(workspaceName: cmd.workspaceName)

    if projects.isEmpty {
      print("No projects found in workspace '\(cmd.workspaceName)'")
    } else {
      print("Projects in workspace '\(cmd.workspaceName)':")
      for (index, project) in projects.enumerated() {
        if cmd.verbose || verbose {
          print("  \(index + 1). \(project)")
        } else {
          print("  \(project)")
        }
      }

      if cmd.verbose || verbose {
        print("\nTotal projects: \(projects.count)")
      }
    }
  }
}
