//
// ListTreeCommand.swift
// xcodeproj-cli
//
// ArgumentParser command for listing the project structure as a tree
//

import ArgumentParser
import Foundation

/// ArgumentParser command for listing the complete project structure as a tree
struct ListTreeCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "list-tree",
    abstract: "List the complete project structure as a tree"
  )

  @OptionGroup var global: GlobalOptions

  @Option(
    name: [.customLong("target"), .customShort("t")],
    help: "Optional: show tree for files in specified target only")
  var target: String?

  @MainActor
  func run() async throws {
    let services = try ProjectServiceFactory.create(from: global, readOnly: true)

    if let targetName = target {
      try services.utility.listTargetTree(targetName: targetName)
    } else {
      services.utility.listProjectTree()
    }
  }
}
