//
// ListInvalidReferencesCommand.swift
// xcodeproj-cli
//
// ArgumentParser command for listing invalid file references in the project
//

import ArgumentParser
import Foundation

/// ArgumentParser command for listing invalid file references in the project
struct ListInvalidReferencesCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "list-invalid-references",
    abstract: "List invalid file references in the project"
  )

  @OptionGroup var global: GlobalOptions

  @MainActor
  func run() async throws {
    let services = try ProjectServiceFactory.create(from: global, readOnly: true)
    services.utility.listInvalidReferences()
  }
}
