//
// ListSwiftPackagesCommand.swift
// xcodeproj-cli
//
// ArgumentParser command for listing Swift Package dependencies
//

import ArgumentParser
import Foundation

/// ArgumentParser command for listing Swift Package dependencies in the project
struct ListSwiftPackagesCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "list-swift-packages",
    abstract: "List Swift Package dependencies in the project"
  )

  @OptionGroup var global: GlobalOptions

  @MainActor
  func run() async throws {
    let services = try ProjectServiceFactory.create(from: global, readOnly: true)
    services.utility.listSwiftPackages()
  }
}
