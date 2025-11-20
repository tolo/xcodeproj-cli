//
// XcodeProjCLI.swift
// xcodeproj-cli
//

import ArgumentParser
import Foundation

/// Main CLI command structure using ArgumentParser
@main
struct XcodeProjCLI: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "xcodeproj-cli",
    abstract: "A powerful command-line tool for Xcode project manipulation",
    version: "2.4.0",
    subcommands: [
      // File Operations (6)
      AddFileCommand.self,
      RemoveFileCommand.self,
      MoveFileCommand.self,
      AddFolderCommand.self,
      AddFilesCommand.self,
      AddSyncFolderCommand.self,

      // Group Operations (4)
      AddGroupCommand.self,
      CreateGroupsCommand.self,
      ListGroupsCommand.self,
      RemoveGroupCommand.self,

      // Target Operations (7)
      AddTargetCommand.self,
      DuplicateTargetCommand.self,
      RemoveTargetCommand.self,
      AddDependencyCommand.self,
      AddTargetFileCommand.self,
      RemoveTargetFileCommand.self,
      ListTargetsCommand.self,

      // Build Configuration (6)
      SetBuildSettingCommand.self,
      RemoveBuildSettingCommand.self,
      GetBuildSettingsCommand.self,
      ListBuildSettingsCommand.self,
      ListBuildConfigsCommand.self,
      AddBuildPhaseCommand.self,

      // Framework Commands (1)
      AddFrameworkCommand.self,

      // Package Commands (4)
      AddSwiftPackageCommand.self,
      RemoveSwiftPackageCommand.self,
      ListSwiftPackagesCommand.self,
      UpdateSwiftPackagesCommand.self,

      // Inspection & Validation (6)
      ValidateCommand.self,
      ListFilesCommand.self,
      ListTreeCommand.self,
      ListInvalidReferencesCommand.self,
      RemoveInvalidReferencesCommand.self,
      ValidateProductsCommand.self,

      // Path Operations (2)
      UpdatePathsCommand.self,
      UpdatePathsMapCommand.self,

      // Product Reference Commands (4)
      RepairProductReferencesCommand.self,
      AddProductReferenceCommand.self,
      RepairProjectCommand.self,
      RepairTargetsCommand.self,

      // Scheme Commands (8)
      CreateSchemeCommand.self,
      DuplicateSchemeCommand.self,
      RemoveSchemeCommand.self,
      ListSchemesCommand.self,
      SetSchemeConfigCommand.self,
      AddSchemeTargetCommand.self,
      EnableTestCoverageCommand.self,
      SetTestParallelCommand.self,

      // Workspace Commands (6)
      CreateWorkspaceCommand.self,
      AddProjectToWorkspaceCommand.self,
      RemoveProjectFromWorkspaceCommand.self,
      ListWorkspaceProjectsCommand.self,
      AddProjectReferenceCommand.self,
      AddCrossProjectDependencyCommand.self,
    ],
    helpNames: [.short, .long]
  )

  @OptionGroup var global: GlobalOptions

  @MainActor
  func run() async throws {
    // When no subcommand is specified, show help
    throw CleanExit.helpRequest(self)
  }
}
