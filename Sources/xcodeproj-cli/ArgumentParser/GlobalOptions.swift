//
// GlobalOptions.swift
// xcodeproj-cli
//

import ArgumentParser
import Foundation

/// Shared global options available to all commands
struct GlobalOptions: ParsableArguments {
  @Option(
    name: [.customLong("project"), .customShort("p")],
    help: "Path to .xcodeproj file (default: looks for *.xcodeproj in current directory)")
  var projectPath: String?

  @Option(
    name: [.customLong("workspace"), .customShort("w")],
    help: "Path to .xcworkspace file")
  var workspacePath: String?

  @Flag(
    name: [.customLong("verbose"), .customShort("V")],
    help: "Enable verbose output with performance metrics")
  var verbose = false

  @Flag(
    name: [.customLong("dry-run")],
    help: "Preview changes without saving")
  var dryRun = false
}
