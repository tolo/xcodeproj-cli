//
// RemoveSwiftPackageCommand.swift
// xcodeproj-cli
//
// ArgumentParser command for removing Swift Package dependencies
//

import ArgumentParser
import Foundation

/// ArgumentParser command for removing Swift Package dependencies from the project
struct RemoveSwiftPackageCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "remove-swift-package",
    abstract: "Remove Swift Package dependency from the project"
  )

  @OptionGroup var global: GlobalOptions

  @Argument(help: "Package repository URL to remove")
  var url: String

  @MainActor
  func run() async throws {
    let services = try ProjectServiceFactory.create(from: global)
    try services.utility.removeSwiftPackage(url: url)
    try services.save()

    print("✅ Swift Package '\(url)' removed from project")
  }
}
