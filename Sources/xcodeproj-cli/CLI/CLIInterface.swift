//
// CLIInterface.swift
// xcodeproj-cli
//
// Command-line interface definitions and help system
//

import Foundation

/// Main CLI interface for xcodeproj-cli
struct CLIInterface {
  static let version = "2.2.0"

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

      COMMON COMMANDS:

      File & Folder Operations:
        add-file <file> --group <group> --targets <target1,target2>
          Add file to project (short: -g, -t)
        add-folder <folder> --group <group> --targets <targets> [--recursive]
          Add folder contents to project
        remove-file <file> [--targets <targets>]
          Remove file from project or specific targets
        create-groups <group1/subgroup> [<group2>...]
          Create group hierarchies

      Target Management:
        list-targets                    List all targets in project
        add-target <name> --type <type> --bundle-id <id>
          Create new target (types: app, framework, test)
        duplicate-target <source> <destination>
          Clone existing target with new name
        add-dependency <target> --depends-on <other-target>
          Add target dependency

      Build Configuration:
        list-build-configs [--target <target>]
          Show available build configurations
        set-build-setting <key> <value> --targets <targets> --configs <configs>
          Set build settings for targets/configs
        get-build-settings <target> [--configs <config>]
          Get build settings for a target

      Project Inspection:
        validate                        Check project integrity
        list-tree                       Display project structure as tree
        list-files [<group>]           List files in project or group
        list-groups                     Show group hierarchy

      Swift Packages:
        add-swift-package <url> --version <version> --target <target>
          Add Swift Package dependency
        list-swift-packages             Show all package dependencies
        remove-swift-package <url>      Remove package dependency

      Schemes & Workspaces:
        create-scheme <name> <target>   Create new scheme
        list-schemes                    List all schemes
        create-workspace <name>         Create new workspace
        add-project-to-workspace <workspace> <project>
          Add project to workspace

      For detailed usage of any command, use: xcodeproj-cli <command> --help
      Full documentation: https://github.com/tolo/xcodeproj-cli
      """
    )
  }

  static func printVersion() {
    print("xcodeproj-cli version \(version)")
  }
}
