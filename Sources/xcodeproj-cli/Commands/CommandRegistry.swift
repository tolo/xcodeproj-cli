//
// CommandRegistry.swift
// xcodeproj-cli
//
// Registry for managing all available commands
//

import Foundation
@preconcurrency import XcodeProj

/// Command handler type for dictionary-based registration
typealias CommandHandler = @MainActor (ParsedArguments, XcodeProjUtility) throws -> Void
typealias CommandUsageHandler = () -> Void
typealias WorkspaceCommandHandler = @MainActor (ParsedArguments, Bool) throws -> Void

/// Metadata for a command used in help generation
struct CommandMetadata {
  let name: String
  let description: String
  let category: CommandCategory
}

/// Registry for managing and executing commands
@MainActor
struct CommandRegistry {

  // MARK: - Command Registration

  /// Dictionary of all registered commands
  private static let commands: [String: CommandHandler] = [
    // File Commands
    AddFileCommand.commandName: AddFileCommand.execute,
    AddFilesCommand.commandName: AddFilesCommand.execute,
    AddFolderCommand.commandName: AddFolderCommand.execute,
    AddSyncFolderCommand.commandName: AddSyncFolderCommand.execute,
    RemoveFileCommand.commandName: RemoveFileCommand.execute,
    MoveFileCommand.commandName: MoveFileCommand.execute,

    // Target Commands
    AddTargetCommand.commandName: AddTargetCommand.execute,
    DuplicateTargetCommand.commandName: DuplicateTargetCommand.execute,
    AddDependencyCommand.commandName: AddDependencyCommand.execute,
    ListTargetsCommand.commandName: ListTargetsCommand.execute,
    RemoveTargetCommand.commandName: RemoveTargetCommand.execute,
    AddTargetFileCommand.commandName: AddTargetFileCommand.execute,
    RemoveTargetFileCommand.commandName: RemoveTargetFileCommand.execute,

    // Group Commands
    CreateGroupsCommand.commandName: CreateGroupsCommand.execute,
    ListGroupsCommand.commandName: ListGroupsCommand.execute,
    RemoveGroupCommand.commandName: RemoveGroupCommand.execute,

    // Build Commands
    SetBuildSettingCommand.commandName: SetBuildSettingCommand.execute,
    GetBuildSettingsCommand.commandName: GetBuildSettingsCommand.execute,
    ListBuildSettingsCommand.commandName: ListBuildSettingsCommand.execute,
    AddBuildPhaseCommand.commandName: AddBuildPhaseCommand.execute,
    ListBuildConfigsCommand.commandName: ListBuildConfigsCommand.execute,

    // Framework Commands
    AddFrameworkCommand.commandName: AddFrameworkCommand.execute,

    // Package Commands
    AddSwiftPackageCommand.commandName: AddSwiftPackageCommand.execute,
    RemoveSwiftPackageCommand.commandName: RemoveSwiftPackageCommand.execute,
    ListSwiftPackagesCommand.commandName: ListSwiftPackagesCommand.execute,
    UpdateSwiftPackagesCommand.commandName: UpdateSwiftPackagesCommand.execute,

    // Inspection Commands
    ValidateCommand.commandName: ValidateCommand.execute,
    ListFilesCommand.commandName: ListFilesCommand.execute,
    ListTreeCommand.commandName: ListTreeCommand.execute,
    ListInvalidReferencesCommand.commandName: ListInvalidReferencesCommand.execute,
    RemoveInvalidReferencesCommand.commandName: RemoveInvalidReferencesCommand.execute,

    // Path Commands
    UpdatePathsCommand.commandName: UpdatePathsCommand.execute,
    UpdatePathsMapCommand.commandName: UpdatePathsMapCommand.execute,

    // Scheme Commands
    CreateSchemeCommand.commandName: CreateSchemeCommand.execute,
    DuplicateSchemeCommand.commandName: DuplicateSchemeCommand.execute,
    RemoveSchemeCommand.commandName: RemoveSchemeCommand.execute,
    ListSchemesCommand.commandName: ListSchemesCommand.execute,
    SetSchemeConfigCommand.commandName: SetSchemeConfigCommand.execute,
    AddSchemeTargetCommand.commandName: AddSchemeTargetCommand.execute,
    EnableTestCoverageCommand.commandName: EnableTestCoverageCommand.execute,
    SetTestParallelCommand.commandName: SetTestParallelCommand.execute,

    // Workspace Commands
    "create-workspace": CreateWorkspaceCommand.execute,
    "add-project-to-workspace": AddProjectToWorkspaceCommand.execute,
    "remove-project-from-workspace": RemoveProjectFromWorkspaceCommand.execute,
    "list-workspace-projects": ListWorkspaceProjectsCommand.execute,
    "add-project-reference": AddProjectReferenceCommand.execute,
    "add-cross-project-dependency": AddCrossProjectDependencyCommand.execute,
  ]

  /// Set of read-only commands
  private static let readOnlyCommands: Set<String> = [
    // Inspection Commands
    ValidateCommand.commandName,
    ListFilesCommand.commandName,
    ListTreeCommand.commandName,
    ListInvalidReferencesCommand.commandName,

    // List Commands
    ListTargetsCommand.commandName,
    ListGroupsCommand.commandName,
    ListBuildConfigsCommand.commandName,
    ListBuildSettingsCommand.commandName,
    GetBuildSettingsCommand.commandName,
    ListSwiftPackagesCommand.commandName,
    ListSchemesCommand.commandName,
    "list-workspace-projects",
  ]

  /// Dictionary of command usage handlers
  private static let usageHandlers: [String: CommandUsageHandler] = [
    // File Commands
    AddFileCommand.commandName: AddFileCommand.printUsage,
    AddFilesCommand.commandName: AddFilesCommand.printUsage,
    AddFolderCommand.commandName: AddFolderCommand.printUsage,
    AddSyncFolderCommand.commandName: AddSyncFolderCommand.printUsage,
    RemoveFileCommand.commandName: RemoveFileCommand.printUsage,
    MoveFileCommand.commandName: MoveFileCommand.printUsage,

    // Target Commands
    AddTargetCommand.commandName: AddTargetCommand.printUsage,
    DuplicateTargetCommand.commandName: DuplicateTargetCommand.printUsage,
    AddDependencyCommand.commandName: AddDependencyCommand.printUsage,
    ListTargetsCommand.commandName: ListTargetsCommand.printUsage,
    RemoveTargetCommand.commandName: RemoveTargetCommand.printUsage,
    AddTargetFileCommand.commandName: AddTargetFileCommand.printUsage,
    RemoveTargetFileCommand.commandName: RemoveTargetFileCommand.printUsage,

    // Group Commands
    CreateGroupsCommand.commandName: CreateGroupsCommand.printUsage,
    ListGroupsCommand.commandName: ListGroupsCommand.printUsage,
    RemoveGroupCommand.commandName: RemoveGroupCommand.printUsage,

    // Build Commands
    SetBuildSettingCommand.commandName: SetBuildSettingCommand.printUsage,
    GetBuildSettingsCommand.commandName: GetBuildSettingsCommand.printUsage,
    ListBuildSettingsCommand.commandName: ListBuildSettingsCommand.printUsage,
    AddBuildPhaseCommand.commandName: AddBuildPhaseCommand.printUsage,
    ListBuildConfigsCommand.commandName: ListBuildConfigsCommand.printUsage,

    // Framework Commands
    AddFrameworkCommand.commandName: AddFrameworkCommand.printUsage,

    // Package Commands
    AddSwiftPackageCommand.commandName: AddSwiftPackageCommand.printUsage,
    RemoveSwiftPackageCommand.commandName: RemoveSwiftPackageCommand.printUsage,
    ListSwiftPackagesCommand.commandName: ListSwiftPackagesCommand.printUsage,
    UpdateSwiftPackagesCommand.commandName: UpdateSwiftPackagesCommand.printUsage,

    // Inspection Commands
    ValidateCommand.commandName: ValidateCommand.printUsage,
    ListFilesCommand.commandName: ListFilesCommand.printUsage,
    ListTreeCommand.commandName: ListTreeCommand.printUsage,
    ListInvalidReferencesCommand.commandName: ListInvalidReferencesCommand.printUsage,
    RemoveInvalidReferencesCommand.commandName: RemoveInvalidReferencesCommand.printUsage,

    // Path Commands
    UpdatePathsCommand.commandName: UpdatePathsCommand.printUsage,
    UpdatePathsMapCommand.commandName: UpdatePathsMapCommand.printUsage,

    // Scheme Commands
    CreateSchemeCommand.commandName: CreateSchemeCommand.printUsage,
    DuplicateSchemeCommand.commandName: DuplicateSchemeCommand.printUsage,
    RemoveSchemeCommand.commandName: RemoveSchemeCommand.printUsage,
    ListSchemesCommand.commandName: ListSchemesCommand.printUsage,
    SetSchemeConfigCommand.commandName: SetSchemeConfigCommand.printUsage,
    AddSchemeTargetCommand.commandName: AddSchemeTargetCommand.printUsage,
    EnableTestCoverageCommand.commandName: EnableTestCoverageCommand.printUsage,
    SetTestParallelCommand.commandName: SetTestParallelCommand.printUsage,

    // Workspace Commands
    "create-workspace": CreateWorkspaceCommand.printUsage,
    "add-project-to-workspace": AddProjectToWorkspaceCommand.printUsage,
    "remove-project-from-workspace": RemoveProjectFromWorkspaceCommand.printUsage,
    "list-workspace-projects": ListWorkspaceProjectsCommand.printUsage,
    "add-project-reference": AddProjectReferenceCommand.printUsage,
    "add-cross-project-dependency": AddCrossProjectDependencyCommand.printUsage,
  ]

  // MARK: - Public Methods

  /// Execute a command by name with given arguments
  static func execute(command: String, arguments: ParsedArguments, utility: XcodeProjUtility) throws
  {
    guard let handler = commands[command] else {
      throw ProjectError.invalidArguments("Unknown command: \(command)")
    }

    try handler(arguments, utility)
  }

  /// Check if a command is read-only (doesn't modify the project)
  static func isReadOnlyCommand(_ command: String) -> Bool {
    return readOnlyCommands.contains(command)
  }

  /// Get list of all available commands
  static func availableCommands() -> [String] {
    return Array(commands.keys).sorted()
  }

  /// Dictionary of workspace-specific commands
  private static let workspaceCommands: [String: WorkspaceCommandHandler] = [
    "create-workspace": CreateWorkspaceCommand.executeAsWorkspaceCommand,
    "add-project-to-workspace": AddProjectToWorkspaceCommand.executeAsWorkspaceCommand,
    "remove-project-from-workspace": RemoveProjectFromWorkspaceCommand.executeAsWorkspaceCommand,
    "list-workspace-projects": ListWorkspaceProjectsCommand.executeAsWorkspaceCommand,
  ]

  /// Execute a workspace command that doesn't require a project context
  static func executeWorkspaceCommand(command: String, arguments: ParsedArguments, verbose: Bool)
    throws
  {
    guard let handler = workspaceCommands[command] else {
      throw ProjectError.invalidArguments("Unknown workspace command: \(command)")
    }

    try handler(arguments, verbose)
  }

  /// Print usage information for a specific command
  static func printCommandUsage(_ command: String) {
    if let usageHandler = usageHandlers[command] {
      usageHandler()
    } else {
      print("Unknown command: \(command)")
    }
  }

  /// Get all command metadata organized by category
  static func getAllCommandMetadata() -> [CommandCategory: [CommandMetadata]] {
    var metadata: [CommandCategory: [CommandMetadata]] = [:]

    // File Commands
    metadata[.fileOperations] = [
      CommandMetadata(
        name: AddFileCommand.commandName, description: AddFileCommand.description,
        category: .fileOperations),
      CommandMetadata(
        name: AddFilesCommand.commandName, description: AddFilesCommand.description,
        category: .fileOperations),
      CommandMetadata(
        name: AddFolderCommand.commandName, description: AddFolderCommand.description,
        category: .fileOperations),
      CommandMetadata(
        name: AddSyncFolderCommand.commandName, description: AddSyncFolderCommand.description,
        category: .fileOperations),
      CommandMetadata(
        name: MoveFileCommand.commandName, description: MoveFileCommand.description,
        category: .fileOperations),
      CommandMetadata(
        name: RemoveFileCommand.commandName, description: RemoveFileCommand.description,
        category: .fileOperations),
    ]

    // Target Commands
    metadata[.targetManagement] = [
      CommandMetadata(
        name: AddTargetCommand.commandName, description: AddTargetCommand.description,
        category: .targetManagement),
      CommandMetadata(
        name: AddTargetFileCommand.commandName, description: AddTargetFileCommand.description,
        category: .targetManagement),
      CommandMetadata(
        name: DuplicateTargetCommand.commandName, description: DuplicateTargetCommand.description,
        category: .targetManagement),
      CommandMetadata(
        name: RemoveTargetCommand.commandName, description: RemoveTargetCommand.description,
        category: .targetManagement),
      CommandMetadata(
        name: RemoveTargetFileCommand.commandName, description: RemoveTargetFileCommand.description,
        category: .targetManagement),
      CommandMetadata(
        name: AddDependencyCommand.commandName, description: AddDependencyCommand.description,
        category: .targetManagement),
      CommandMetadata(
        name: ListTargetsCommand.commandName, description: ListTargetsCommand.description,
        category: .targetManagement),
    ]

    // Group Commands
    metadata[.groupOperations] = [
      CommandMetadata(
        name: CreateGroupsCommand.commandName, description: CreateGroupsCommand.description,
        category: .groupOperations),
      CommandMetadata(
        name: ListGroupsCommand.commandName, description: ListGroupsCommand.description,
        category: .groupOperations),
      CommandMetadata(
        name: RemoveGroupCommand.commandName, description: RemoveGroupCommand.description,
        category: .groupOperations),
    ]

    // Build Commands
    metadata[.buildConfiguration] = [
      CommandMetadata(
        name: SetBuildSettingCommand.commandName, description: SetBuildSettingCommand.description,
        category: .buildConfiguration),
      CommandMetadata(
        name: GetBuildSettingsCommand.commandName, description: GetBuildSettingsCommand.description,
        category: .buildConfiguration),
      CommandMetadata(
        name: ListBuildSettingsCommand.commandName,
        description: ListBuildSettingsCommand.description, category: .buildConfiguration),
      CommandMetadata(
        name: AddBuildPhaseCommand.commandName, description: AddBuildPhaseCommand.description,
        category: .buildConfiguration),
      CommandMetadata(
        name: ListBuildConfigsCommand.commandName, description: ListBuildConfigsCommand.description,
        category: .buildConfiguration),
    ]

    // Framework Commands
    metadata[.frameworks] = [
      CommandMetadata(
        name: AddFrameworkCommand.commandName, description: AddFrameworkCommand.description,
        category: .frameworks)
    ]

    // Package Commands
    metadata[.swiftPackages] = [
      CommandMetadata(
        name: AddSwiftPackageCommand.commandName, description: AddSwiftPackageCommand.description,
        category: .swiftPackages),
      CommandMetadata(
        name: RemoveSwiftPackageCommand.commandName,
        description: RemoveSwiftPackageCommand.description, category: .swiftPackages),
      CommandMetadata(
        name: ListSwiftPackagesCommand.commandName,
        description: ListSwiftPackagesCommand.description, category: .swiftPackages),
      CommandMetadata(
        name: UpdateSwiftPackagesCommand.commandName,
        description: UpdateSwiftPackagesCommand.description, category: .swiftPackages),
    ]

    // Inspection Commands
    metadata[.inspection] = [
      CommandMetadata(
        name: ValidateCommand.commandName, description: ValidateCommand.description,
        category: .inspection),
      CommandMetadata(
        name: ListFilesCommand.commandName, description: ListFilesCommand.description,
        category: .inspection),
      CommandMetadata(
        name: ListTreeCommand.commandName, description: ListTreeCommand.description,
        category: .inspection),
      CommandMetadata(
        name: ListInvalidReferencesCommand.commandName,
        description: ListInvalidReferencesCommand.description, category: .inspection),
      CommandMetadata(
        name: RemoveInvalidReferencesCommand.commandName,
        description: RemoveInvalidReferencesCommand.description, category: .inspection),
    ]

    // Path Commands
    metadata[.pathOperations] = [
      CommandMetadata(
        name: UpdatePathsCommand.commandName, description: UpdatePathsCommand.description,
        category: .pathOperations),
      CommandMetadata(
        name: UpdatePathsMapCommand.commandName, description: UpdatePathsMapCommand.description,
        category: .pathOperations),
    ]

    // Scheme Commands
    metadata[.schemes] = [
      CommandMetadata(
        name: CreateSchemeCommand.commandName, description: CreateSchemeCommand.description,
        category: .schemes),
      CommandMetadata(
        name: DuplicateSchemeCommand.commandName, description: DuplicateSchemeCommand.description,
        category: .schemes),
      CommandMetadata(
        name: RemoveSchemeCommand.commandName, description: RemoveSchemeCommand.description,
        category: .schemes),
      CommandMetadata(
        name: ListSchemesCommand.commandName, description: ListSchemesCommand.description,
        category: .schemes),
      CommandMetadata(
        name: SetSchemeConfigCommand.commandName, description: SetSchemeConfigCommand.description,
        category: .schemes),
      CommandMetadata(
        name: AddSchemeTargetCommand.commandName, description: AddSchemeTargetCommand.description,
        category: .schemes),
      CommandMetadata(
        name: EnableTestCoverageCommand.commandName,
        description: EnableTestCoverageCommand.description, category: .schemes),
      CommandMetadata(
        name: SetTestParallelCommand.commandName, description: SetTestParallelCommand.description,
        category: .schemes),
    ]

    // Workspace Commands
    metadata[.workspaces] = [
      CommandMetadata(
        name: "create-workspace", description: CreateWorkspaceCommand.description,
        category: .workspaces),
      CommandMetadata(
        name: "add-project-to-workspace", description: AddProjectToWorkspaceCommand.description,
        category: .workspaces),
      CommandMetadata(
        name: "remove-project-from-workspace",
        description: RemoveProjectFromWorkspaceCommand.description, category: .workspaces),
      CommandMetadata(
        name: "list-workspace-projects", description: ListWorkspaceProjectsCommand.description,
        category: .workspaces),
    ]

    // Cross-Project Commands
    metadata[.crossProject] = [
      CommandMetadata(
        name: "add-project-reference", description: AddProjectReferenceCommand.description,
        category: .crossProject),
      CommandMetadata(
        name: "add-cross-project-dependency",
        description: AddCrossProjectDependencyCommand.description, category: .crossProject),
    ]

    return metadata
  }
}
