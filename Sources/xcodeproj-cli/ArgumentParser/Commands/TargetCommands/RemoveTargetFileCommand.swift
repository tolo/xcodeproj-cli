//
// RemoveTargetFileCommand.swift
// xcodeproj-cli
//
// ArgumentParser command for removing a file from a target's compile sources
//

import ArgumentParser
import Foundation

/// ArgumentParser command for removing a file from a target's compile sources or resources without removing it from the project
struct RemoveTargetFileCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "remove-target-file",
    abstract:
      "Remove a file from a target's compile sources or resources without removing it from the project"
  )

  @OptionGroup var global: GlobalOptions

  @Argument(
    help: """
      Path to the file in the project
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

    // Remove file from each target
    for targetName in targets {
      try services.utility.removeFileFromTarget(path: validatedPath, targetName: targetName)
    }

    try services.save()

    let targetList = targets.joined(separator: ", ")
    print("✅ File '\(filePath)' removed from target(s): \(targetList)")
  }
}
