//
// AddTargetFileCommand.swift
// xcodeproj-cli
//
// ArgumentParser command for adding an existing file to a target's compile sources
//

import ArgumentParser
import Foundation

/// ArgumentParser command for adding an existing file to a target's compile sources or resources
struct AddTargetFileCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "add-target-file",
    abstract: "Add an existing file to a target's compile sources or resources"
  )

  @OptionGroup var global: GlobalOptions

  @Argument(
    help: """
      Path to the file (must already exist in project)
      Can be: filename only (Model.swift), partial path (Sources/Model.swift), or full project path
      """
  )
  var filePath: String

  @Option(
    name: [.customLong("targets"), .customLong("target"), .customShort("t")],
    parsing: .upToNextOption,
    help: "Target names (accepts single or multiple targets)"
  )
  var targets: [String]

  @MainActor
  func run() async throws {
    // Validate path for security (path traversal protection)
    let validatedPath = try SecurityUtils.validatePath(filePath)

    let services = try ProjectServiceFactory.create(from: global)

    // Validate all targets exist before proceeding
    let projectTargets = Set(services.utility.pbxproj.nativeTargets.map { $0.name })
    let missingTargets = targets.filter { !projectTargets.contains($0) }

    guard missingTargets.isEmpty else {
      let missing = missingTargets.joined(separator: ", ")
      throw ProjectError.targetNotFound(missing)
    }

    // Add file to each target
    for targetName in targets {
      try services.utility.addFileToTarget(path: validatedPath, targetName: targetName)
    }

    try services.save()

    let targetList = targets.joined(separator: ", ")
    print("✅ File '\(filePath)' added to target(s): \(targetList)")
  }
}
