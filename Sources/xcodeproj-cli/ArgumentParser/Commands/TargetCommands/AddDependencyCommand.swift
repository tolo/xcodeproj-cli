//
// AddDependencyCommand.swift
// xcodeproj-cli
//
// ArgumentParser command for adding a dependency between targets
//

import ArgumentParser
import Foundation

/// ArgumentParser command for adding a dependency relationship between targets
struct AddDependencyCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "add-dependency",
    abstract: "Add a dependency relationship between targets"
  )

  @OptionGroup var global: GlobalOptions

  @Argument(help: "Target that will depend on another target")
  var target: String

  @Option(
    name: .customLong("depends-on"),
    help: "Target that will be depended upon"
  )
  var dependsOn: String

  @MainActor
  func run() async throws {
    let services = try ProjectServiceFactory.create(from: global)
    try services.utility.addDependency(to: target, dependsOn: dependsOn)
    try services.save()
    print("✅ Dependency added: '\(target)' now depends on '\(dependsOn)'")
  }
}
