//
// RemoveInvalidReferencesCommand.swift
// xcodeproj-cli
//
// ArgumentParser command for removing invalid file references from the project
//

import ArgumentParser
import Foundation

/// ArgumentParser command for removing invalid file references from the project
struct RemoveInvalidReferencesCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "remove-invalid-references",
    abstract: "Remove invalid file references from the project"
  )

  @OptionGroup var global: GlobalOptions

  @MainActor
  func run() async throws {
    let services = try ProjectServiceFactory.create(from: global)
    services.utility.removeInvalidReferences()
    try services.save()

    print("✅ Invalid references removed from project")
  }
}
