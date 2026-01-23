//
// ProjectError.swift
// xcodeproj-cli
//
// Error types for xcodeproj-cli operations
//

import Foundation

/// Comprehensive error types for xcodeproj-cli operations
enum ProjectError: Error, CustomStringConvertible {
  case fileAlreadyExists(String)
  case groupNotFound(String)
  case targetNotFound(String)
  case invalidArguments(String)
  case invalidConfiguration(String)
  case operationFailed(String)

  // Workspace-specific errors
  case workspaceNotFound(String)
  case workspaceLoadFailed(String, Error)
  case projectNotFoundInWorkspace(String, String)

  // Scheme-specific errors
  case schemeNotFound(String)
  case schemeLoadFailed(String, Error)
  case schemeInvalidConfiguration(String)

  // Configuration-specific errors
  case configurationNotFound(String)
  case buildConfigurationListMissing(String)

  // Localization-specific errors
  case localizationAlreadyExists(String)
  case localizationNotFound(String)
  case variantGroupNotFound(String)

  // Cross-project errors
  case externalProjectNotFound(String)
  case dependencyAlreadyExists(String, String)
  case dependencyNotFound(String, String)

  // Transaction errors
  case transactionNotActive
  case transactionAlreadyActive

  // Feature availability errors
  case featureNotAvailable(String)

  var description: String {
    switch self {
    case .fileAlreadyExists(let path):
      return "File already exists: \(path)"
    case .groupNotFound(let name):
      let hasSlashes = name.contains("/")

      if hasSlashes {
        // User tried path but it didn't resolve
        return """
          Group not found: '\(name)'

          The path '\(name)' could not be resolved to an existing group.

          To fix this:
            • Run 'list-groups --show-names' to see valid paths and names
            • Create the hierarchy first: 'create-groups \(name)'
            • Try using just the last component: '\(name.split(separator: "/").last ?? "")'
          """
      } else {
        // User tried simple name
        return """
          Group not found: '\(name)'

          To fix this:
            • Run 'list-groups --show-names' to see all available groups
            • Create the group: 'create-groups \(name)'
            • Try using a full path if the group is nested
          """
      }
    case .targetNotFound(let name):
      return "Target not found: \(name). Use 'list-targets' to see available targets."
    case .invalidArguments(let msg):
      return "Invalid arguments: \(msg)"
    case .invalidConfiguration(let msg):
      return "Invalid configuration: \(msg)"
    case .operationFailed(let msg):
      return "Operation failed: \(msg)"

    case .workspaceNotFound(let name):
      return "Workspace not found: \(name). Use 'create-workspace' to create it first."
    case .workspaceLoadFailed(let name, let error):
      return "Failed to load workspace '\(name)': \(error.localizedDescription)"
    case .projectNotFoundInWorkspace(let project, let workspace):
      return "Project '\(project)' not found in workspace '\(workspace)'"

    case .schemeNotFound(let name):
      return "Scheme not found: \(name). Use 'list-schemes' to see available schemes."
    case .schemeLoadFailed(let name, let error):
      return "Failed to load scheme '\(name)': \(error.localizedDescription)"
    case .schemeInvalidConfiguration(let msg):
      return "Invalid scheme configuration: \(msg)"

    case .configurationNotFound(let name):
      return
        "Build configuration not found: \(name). Use 'list-build-configs' to see available configurations."
    case .buildConfigurationListMissing(let target):
      return "Build configuration list missing for target: \(target)"

    case .localizationAlreadyExists(let lang):
      return "Localization already exists: \(lang)"
    case .localizationNotFound(let lang):
      return
        "Localization not found: \(lang). Use 'list-localizations' to see available localizations."
    case .variantGroupNotFound(let name):
      return "Variant group not found: \(name)"

    case .externalProjectNotFound(let path):
      return
        "External project not found: \(path). Add project reference first using 'add-project-reference'."
    case .dependencyAlreadyExists(let target, let dependency):
      return "Dependency already exists: \(target) -> \(dependency)"
    case .dependencyNotFound(let target, let dependency):
      return "Dependency not found: \(target) -> \(dependency)"

    case .transactionNotActive:
      return "No active transaction. Begin a transaction first."
    case .transactionAlreadyActive:
      return "Transaction already active. Commit or rollback the current transaction first."

    case .featureNotAvailable(let msg):
      return "Feature not available: \(msg)"
    }
  }
}
