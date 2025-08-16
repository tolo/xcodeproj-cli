//
// ListSchemesCommand.swift
// xcodeproj-cli
//
// Command for listing Xcode schemes
//

import Foundation
@preconcurrency import PathKit
@preconcurrency import XcodeProj

struct ListSchemesCommand: Command {
  static let commandName = "list-schemes"
  static let description = "List all schemes in the project"

  static let category: CommandCategory = .schemes

  static let isReadOnly = true
  let showShared: Bool
  let showUser: Bool
  let verbose: Bool

  init(arguments: ParsedArguments) throws {
    let hasSharedFlag = arguments.boolFlags.contains("--shared")
    let hasUserFlag = arguments.boolFlags.contains("--user")

    // If neither flag is specified, show both
    if !hasSharedFlag && !hasUserFlag {
      self.showShared = true
      self.showUser = true
    } else {
      self.showShared = hasSharedFlag
      self.showUser = hasUserFlag
    }

    self.verbose = arguments.boolFlags.contains("--verbose")
  }

  @MainActor
  func execute(with xcodeproj: XcodeProj, projectPath: Path) throws {
    let schemeManager = SchemeManager(xcodeproj: xcodeproj, projectPath: projectPath)

    var allSchemes: [(name: String, type: String)] = []

    if showShared {
      let sharedSchemes = try schemeManager.listSchemes(shared: true)
      allSchemes.append(contentsOf: sharedSchemes.map { ($0, "shared") })
    }

    if showUser {
      let userSchemes = try schemeManager.listSchemes(shared: false)
      allSchemes.append(contentsOf: userSchemes.map { ($0, "user") })
    }

    if allSchemes.isEmpty {
      print("No schemes found")
      return
    }

    print("📋 Schemes:")

    if verbose {
      // Group by type for verbose output
      if showShared {
        let sharedSchemes = allSchemes.filter { $0.type == "shared" }
        if !sharedSchemes.isEmpty {
          print("\n  Shared Schemes:")
          for scheme in sharedSchemes {
            print("    - \(scheme.name)")
          }
        }
      }

      if showUser {
        let userSchemes = allSchemes.filter { $0.type == "user" }
        if !userSchemes.isEmpty {
          print("\n  User Schemes:")
          for scheme in userSchemes {
            print("    - \(scheme.name)")
          }
        }
      }
    } else {
      // Simple list for non-verbose
      for scheme in allSchemes.sorted(by: { $0.name < $1.name }) {
        let typeIndicator = verbose ? " (\(scheme.type))" : ""
        print("  - \(scheme.name)\(typeIndicator)")
      }
    }

    print("\nTotal: \(allSchemes.count) scheme(s)")
  }

  static func printUsage() {
    print(
      """
      Usage: list-schemes [options]

      Options:
        --shared          Show only shared schemes
        --user            Show only user-specific schemes
        --verbose         Show detailed output with scheme types

      Examples:
        list-schemes
        list-schemes --shared
        list-schemes --verbose
      """)
  }

  static func execute(with arguments: ParsedArguments, utility: XcodeProjUtility) throws {
    let cmd = try ListSchemesCommand(arguments: arguments)
    try cmd.execute(with: utility.xcodeproj, projectPath: utility.projectPath)
  }
}
