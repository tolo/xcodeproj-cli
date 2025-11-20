//
// AddSwiftPackageCommand.swift
// xcodeproj-cli
//
// ArgumentParser command for adding Swift Package dependencies
//

import ArgumentParser
import Foundation

/// ArgumentParser command for adding Swift Package dependencies to the project
struct AddSwiftPackageCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "add-swift-package",
    abstract: "Add Swift Package dependency to the project"
  )

  @OptionGroup var global: GlobalOptions

  @Argument(help: "Package repository URL (https:// or git@)")
  var url: String

  @Option(
    name: [.customLong("version"), .customShort("v")],
    help: "Version requirement (e.g., '1.0.0', 'from: 1.0.0')")
  var version: String?

  @Option(
    name: [.customLong("branch"), .customShort("b")],
    help: "Branch requirement (e.g., 'main', 'develop')")
  var branch: String?

  @Option(
    name: [.customLong("commit"), .customShort("c")],
    help: "Commit hash requirement")
  var commit: String?

  @Option(
    name: [.customLong("target"), .customShort("t")],
    help: "Optional: target to add package to")
  var target: String?

  @MainActor
  func run() async throws {
    // Check for conflicting flags
    let versionFlags = [version, branch, commit].compactMap { $0 }
    if versionFlags.count > 1 {
      throw ValidationError(
        "Cannot specify multiple version requirements (--version, --branch, --commit are mutually exclusive)"
      )
    }

    if versionFlags.isEmpty {
      throw ValidationError(
        "Must specify one of: --version, --branch, or --commit flag")
    }

    // Build requirement string
    let requirement: String
    if let version = version {
      requirement = version.hasPrefix("from:") || version.hasPrefix("exact:") ? version : version
    } else if let branch = branch {
      requirement = "branch:\(branch)"
    } else if let commit = commit {
      requirement = "commit:\(commit)"
    } else {
      throw ValidationError("Must specify one of: --version, --branch, or --commit flag")
    }

    let services = try ProjectServiceFactory.create(from: global)
    try services.utility.addSwiftPackage(url: url, requirement: requirement, to: target)
    try services.save()

    let targetMsg = target.map { " to target '\($0)'" } ?? ""
    print("✅ Swift Package '\(url)' added with requirement '\(requirement)'\(targetMsg)")
  }
}
