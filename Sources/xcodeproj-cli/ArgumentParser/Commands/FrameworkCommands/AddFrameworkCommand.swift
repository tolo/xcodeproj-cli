//
// AddFrameworkCommand.swift
// xcodeproj-cli
//
// ArgumentParser command for adding a framework to a target
//

import ArgumentParser
import Foundation

/// ArgumentParser command for adding a framework to a target with optional embedding
struct AddFrameworkCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "add-framework",
    abstract: "Add a framework to a target"
  )

  @OptionGroup var global: GlobalOptions

  @Argument(help: "Name of the framework to add")
  var frameworkName: String

  @Option(
    name: [.customLong("target"), .customShort("t")],
    help: "Target to add the framework to")
  var target: String

  @Flag(
    name: [.customLong("embed"), .customShort("e")],
    help: "Embed the framework in the app bundle")
  var embed = false

  @MainActor
  func run() async throws {
    let services = try ProjectServiceFactory.create(from: global)
    try services.utility.addFramework(name: frameworkName, to: target, embed: embed)
    try services.save()

    let embedMsg = embed ? " (embedded)" : ""
    print("✅ Framework '\(frameworkName)' added to target '\(target)'\(embedMsg)")
  }
}
