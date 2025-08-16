//
// AddProjectToWorkspaceCommand.swift
// xcodeproj-cli
//
// Command for adding projects to workspaces
//

import Foundation
@preconcurrency import PathKit
@preconcurrency import XcodeProj

struct AddProjectToWorkspaceCommand: Command {
  static let commandName = "add-project-to-workspace"
  static let description = "Add a project to an existing workspace"

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

    // Add project to workspace
    try workspaceManager.addProjectToWorkspace(
      workspaceName: workspaceName,
      projectPath: self.projectPath
    )

    if verbose {
      print("  Workspace: \(workspaceName).xcworkspace")
      print("  Added project: \(self.projectPath)")
    }
  }

  static func printUsage() {
    print(
      """
      Usage: add-project-to-workspace <workspace-name> <project-path> [options]

      Arguments:
        workspace-name    Name of the workspace (without .xcworkspace extension)
        project-path      Path to the project to add

      Options:
        --verbose         Show detailed output

      Examples:
        add-project-to-workspace MyWorkspace App.xcodeproj
        add-project-to-workspace MyWorkspace ../Framework/Framework.xcodeproj
      """)
  }

  @MainActor
  static func execute(with arguments: ParsedArguments, utility: XcodeProjUtility) throws {
    let cmd = try AddProjectToWorkspaceCommand(arguments: arguments)
    try cmd.execute(with: utility.xcodeproj, projectPath: utility.projectPath)
  }

  @MainActor
  static func executeAsWorkspaceCommand(with arguments: ParsedArguments, verbose: Bool) throws {
    let cmd = try AddProjectToWorkspaceCommand(arguments: arguments)
    let workspaceManager = WorkspaceManager()

    // Add project to workspace
    try workspaceManager.addProjectToWorkspace(
      workspaceName: cmd.workspaceName,
      projectPath: cmd.projectPath
    )

    if cmd.verbose || verbose {
      print("  Workspace: \(cmd.workspaceName).xcworkspace")
      print("  Added project: \(cmd.projectPath)")
    }
  }
}
