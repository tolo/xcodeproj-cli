//
// CLIInterface.swift
// xcodeproj-cli
//
// Command-line interface definitions and help system
//

import Foundation

/// Main CLI interface for xcodeproj-cli
struct CLIInterface {
  static let version = "2.2.1"

  static func printUsage() {
    print(
      """
      XcodeProj CLI v\(version)
      A powerful command-line tool for Xcode project manipulation

      Usage: xcodeproj-cli [--project <path>] <command> [options]

      Options:
        --project <path>  Path to .xcodeproj file (default: looks for *.xcodeproj in current directory)
        --dry-run         Preview changes without saving
        --verbose, -V     Enable verbose output with performance metrics
        --version         Display version information
        --help, -h        Show this help message

      ALL AVAILABLE COMMANDS:

      File & Folder Operations:
        add-file                        Add file to project
        add-files                       Add multiple files to project
        add-folder                      Add folder contents to project
        add-sync-folder                 Add folder with sync to filesystem
        move-file                       Move file to different group
        remove-file                     Remove file from project

      Target Management:
        add-target                      Create new target
        add-target-file                 Add file to specific targets
        duplicate-target                Clone existing target
        remove-target                   Remove target from project
        remove-target-file              Remove file from specific targets
        add-dependency                  Add target dependency
        list-targets                    List all targets

      Group Operations:
        create-groups                   Create group hierarchies
        list-groups                     Show group hierarchy
        remove-group                    Remove group from project

      Build Configuration:
        set-build-setting               Set build settings
        get-build-settings              Get build settings for target
        list-build-settings             List all build settings
        add-build-phase                 Add build phase to target
        list-build-configs              Show available build configurations

      Frameworks & Dependencies:
        add-framework                   Add framework to targets

      Swift Packages:
        add-swift-package               Add Swift Package dependency
        remove-swift-package            Remove package dependency
        list-swift-packages             Show all package dependencies
        update-swift-packages           Update package dependencies

      Project Inspection & Validation:
        validate                        Check project integrity
        list-files                      List files in project or group
        list-tree                       Display project structure as tree
        list-invalid-references         Show invalid file references
        remove-invalid-references       Clean up invalid references

      Path Operations:
        update-paths                    Update file paths
        update-paths-map                Update paths using mapping file

      Schemes:
        create-scheme                   Create new scheme
        duplicate-scheme                Duplicate existing scheme
        remove-scheme                   Remove scheme
        list-schemes                    List all schemes
        set-scheme-config               Set scheme configuration
        add-scheme-target               Add target to scheme
        enable-test-coverage            Enable code coverage for scheme
        set-test-parallel               Configure parallel testing

      Workspaces:
        create-workspace                Create new workspace
        add-project-to-workspace        Add project to workspace
        remove-project-from-workspace   Remove project from workspace
        list-workspace-projects         List projects in workspace

      Cross-Project:
        add-project-reference           Add reference to another project
        add-cross-project-dependency    Add cross-project dependency

      For detailed usage of any command, use: xcodeproj-cli <command> --help
      Full documentation: https://github.com/tolo/xcodeproj-cli
      """
    )
  }

  static func printVersion() {
    print("xcodeproj-cli version \(version)")
  }
}
