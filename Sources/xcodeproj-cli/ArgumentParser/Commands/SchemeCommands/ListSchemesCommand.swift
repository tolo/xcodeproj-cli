//
// ListSchemesCommand.swift
// xcodeproj-cli
//
// ArgumentParser command for listing Xcode schemes
//

import ArgumentParser
import Foundation
@preconcurrency import PathKit

/// ArgumentParser command for listing schemes (READ-ONLY)
struct ListSchemesCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "list-schemes",
    abstract: "List all schemes in the project"
  )

  @OptionGroup var global: GlobalOptions

  @Flag(help: "Show only shared schemes")
  var shared: Bool = false

  @Flag(help: "Show only user-specific schemes")
  var user: Bool = false

  @MainActor
  func run() async throws {
    let services = try ProjectServiceFactory.create(from: global, readOnly: true)
    let schemeManager = SchemeManager(
      xcodeproj: services.utility.xcodeproj,
      projectPath: services.utility.projectPath
    )

    // If neither flag is specified, show both
    let showShared = !user || shared
    let showUser = user || !shared

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

    if global.verbose {
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
        let typeIndicator = global.verbose ? " (\(scheme.type))" : ""
        print("  - \(scheme.name)\(typeIndicator)")
      }
    }

    print("\nTotal: \(allSchemes.count) scheme(s)")
  }
}
