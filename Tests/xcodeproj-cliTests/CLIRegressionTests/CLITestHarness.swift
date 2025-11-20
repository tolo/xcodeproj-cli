//
// CLITestHarness.swift
// xcodeproj-cli Tests
//
// Test harness for executing CLI commands and capturing output
//

import Foundation
import XCTest

/// Result of executing a CLI command
struct CLICommandResult {
    let exitCode: Int32
    let stdout: String
    let stderr: String
    let success: Bool

    init(exitCode: Int32, stdout: String, stderr: String) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
        self.success = exitCode == 0
    }
}

/// Test harness for executing CLI commands
enum CLITestHarness {

    // MARK: - CLI Execution

    /// Execute a CLI command and capture output
    /// - Parameter arguments: Command line arguments (excluding program name)
    /// - Returns: Result containing exit code and output
    static func executeCommand(_ arguments: [String]) -> CLICommandResult {
        let task = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        // Get path to the built CLI binary
        let binaryPath = cliExecutablePath()

        task.executableURL = URL(fileURLWithPath: binaryPath)
        task.arguments = arguments
        task.standardOutput = outputPipe
        task.standardError = errorPipe

        var stdout = ""
        var stderr = ""
        var exitCode: Int32 = -1

        do {
            try task.run()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

            stdout = String(data: outputData, encoding: .utf8) ?? ""
            stderr = String(data: errorData, encoding: .utf8) ?? ""

            task.waitUntilExit()
            exitCode = task.terminationStatus
        } catch {
            stderr = "Failed to execute command: \(error.localizedDescription)\nBinary path: \(binaryPath)"
            exitCode = -1
        }

        return CLICommandResult(
            exitCode: exitCode,
            stdout: stdout,
            stderr: stderr
        )
    }

    /// Execute a command with a test project
    /// - Parameters:
    ///   - projectPath: Path to test project
    ///   - command: Command to execute
    ///   - args: Additional arguments
    /// - Returns: Command result
    static func executeWithProject(
        _ projectPath: String,
        command: String,
        args: [String] = []
    ) -> CLICommandResult {
        var arguments = ["--project", projectPath, command]
        arguments.append(contentsOf: args)
        return executeCommand(arguments)
    }

    // MARK: - Test Project Management

    /// Create a temporary test project for testing
    /// - Parameter name: Name of the project
    /// - Returns: Path to the created project
    static func createTestProject(named name: String) throws -> String {
        let tempDir = FileManager.default.temporaryDirectory
        let projectDir = tempDir.appendingPathComponent("\(name)_\(UUID().uuidString)")

        // Create directory
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)

        // Copy test project from TestResources
        let testResourcesPath = testResourcesPath()
        let sourceProject = URL(fileURLWithPath: testResourcesPath)
            .appendingPathComponent("TestProject.xcodeproj")

        let destProject = projectDir.appendingPathComponent("TestProject.xcodeproj")

        try FileManager.default.copyItem(at: sourceProject, to: destProject)

        return destProject.path
    }

    /// Clean up a test project
    /// - Parameter projectPath: Path to project to remove
    static func cleanupTestProject(at projectPath: String) {
        let projectURL = URL(fileURLWithPath: projectPath)
        let projectDir = projectURL.deletingLastPathComponent()

        try? FileManager.default.removeItem(at: projectDir)
    }

    // MARK: - Path Utilities

    /// Get path to the CLI executable
    private static func cliExecutablePath() -> String {
        // When running tests, the working directory is the package root
        let workingDir = FileManager.default.currentDirectoryPath
        let binaryPath = URL(fileURLWithPath: workingDir)
            .appendingPathComponent(".build")
            .appendingPathComponent("debug")
            .appendingPathComponent("xcodeproj-cli")
            .path

        // Verify the path exists
        if FileManager.default.fileExists(atPath: binaryPath) {
            return binaryPath
        }

        // Fallback: Try release build
        let releasePath = URL(fileURLWithPath: workingDir)
            .appendingPathComponent(".build")
            .appendingPathComponent("release")
            .appendingPathComponent("xcodeproj-cli")
            .path

        if FileManager.default.fileExists(atPath: releasePath) {
            return releasePath
        }

        // Last resort: return debug path even if it doesn't exist
        // The error will be more clear this way
        return binaryPath
    }

    /// Get path to TestResources directory
    private static func testResourcesPath() -> String {
        // When running tests, the working directory is the package root
        // So we can use a path relative to that
        let workingDir = FileManager.default.currentDirectoryPath
        let testResourcesPath = URL(fileURLWithPath: workingDir)
            .appendingPathComponent("Tests")
            .appendingPathComponent("xcodeproj-cliTests")
            .appendingPathComponent("TestResources")
            .path

        // Verify the path exists
        if FileManager.default.fileExists(atPath: testResourcesPath) {
            return testResourcesPath
        }

        // Fallback: Try Bundle approach
        if let bundleResourcePath = Bundle.module.resourcePath {
            let bundleTestResources = URL(fileURLWithPath: bundleResourcePath)
                .deletingLastPathComponent()
                .appendingPathComponent("TestResources")

            if FileManager.default.fileExists(atPath: bundleTestResources.path) {
                return bundleTestResources.path
            }
        }

        // Last resort: return the path even if it doesn't exist
        // The error will be more clear this way
        return testResourcesPath
    }

    // MARK: - Output Normalization

    /// Normalize output for comparison (remove timestamps, variable paths, etc.)
    /// - Parameter output: Raw output string
    /// - Returns: Normalized output
    static func normalizeOutput(_ output: String) -> String {
        var normalized = output

        // Remove timestamps like [2024-01-01 12:34:56]
        normalized = normalized.replacingOccurrences(
            of: "\\[\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2}\\]",
            with: "[TIMESTAMP]",
            options: .regularExpression
        )

        // Remove temp paths
        normalized = normalized.replacingOccurrences(
            of: "/var/folders/[^\\s]+",
            with: "/tmp/[PATH]",
            options: .regularExpression
        )

        // Remove UUIDs
        normalized = normalized.replacingOccurrences(
            of: "[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}",
            with: "[UUID]",
            options: [.regularExpression, .caseInsensitive]
        )

        return normalized
    }
}
