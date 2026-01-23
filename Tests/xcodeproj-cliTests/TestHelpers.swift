//
// TestHelpers.swift
// xcodeproj-cliTests
//
// Shared utilities and helpers for testing xcodeproj-cli commands
//

import XCTest
import Foundation

/// Helper class for CLI testing utilities
class TestHelpers {
    
    // MARK: - Binary Path Configuration
    
    /// Path to the xcodeproj-cli binary for testing
    static var binaryPath: URL {
        return productsDirectory.appendingPathComponent("xcodeproj-cli")
    }
    
    /// Path to test project directory
    static var testProjectPath: String {
        // Get the current test file's directory and find TestResources
        let testDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        return testDir.appendingPathComponent("TestResources/TestProject.xcodeproj").path
    }
    
    /// Path to backup test project directory
    static var backupProjectPath: String {
        // Get the current test file's directory and find TestResources
        let testDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        return testDir.appendingPathComponent("TestResources/TestProject.xcodeproj.backup").path
    }
    
    // MARK: - Test Project Management
    
    /// Create a backup of the test project before running tests
    static func backupTestProject() throws {
        let projectURL = URL(fileURLWithPath: testProjectPath)
        let backupURL = URL(fileURLWithPath: backupProjectPath)
        
        // Remove existing backup if it exists
        if FileManager.default.fileExists(atPath: backupProjectPath) {
            try FileManager.default.removeItem(at: backupURL)
        }
        
        try FileManager.default.copyItem(at: projectURL, to: backupURL)
    }
    
    /// Restore the test project from backup after running tests
    static func restoreTestProject() throws {
        let projectURL = URL(fileURLWithPath: testProjectPath)
        let backupURL = URL(fileURLWithPath: backupProjectPath)
        
        // Remove current project
        if FileManager.default.fileExists(atPath: testProjectPath) {
            try FileManager.default.removeItem(at: projectURL)
        }
        
        // Restore from backup
        if FileManager.default.fileExists(atPath: backupProjectPath) {
            try FileManager.default.copyItem(at: backupURL, to: projectURL)
        }
    }
    
    // MARK: - Command Execution
    
    /// Result of executing a CLI command
    struct CommandResult {
        let exitCode: Int32
        let output: String
        let error: String
        
        var success: Bool {
            return exitCode == 0
        }
    }
    
    /// Execute a CLI command and return the result
    @discardableResult
    static func runCommand(_ command: String, arguments: [String] = [], timeout: TimeInterval = 30.0) throws -> CommandResult {
        let process = Process()
        process.executableURL = binaryPath
        
        var allArguments = [command]
        allArguments.append(contentsOf: arguments)
        
        // Always add the test project path if not already specified
        if !arguments.contains("--project") {
            allArguments.append("--project")
            allArguments.append(testProjectPath)
        }
        
        process.arguments = allArguments
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        try process.run()
        
        // Wait for completion with timeout using a simpler approach
        let semaphore = DispatchSemaphore(value: 0)
        var didTimeout = false
        
        // Wait for process completion in background
        DispatchQueue.global().async {
            process.waitUntilExit()
            semaphore.signal()
        }
        
        // Wait with timeout
        let timeoutResult = semaphore.wait(timeout: .now() + timeout)
        
        if timeoutResult == .timedOut {
            didTimeout = true
            process.terminate()
            // Wait for the process to actually terminate
            process.waitUntilExit()
        }
        
        if didTimeout {
            throw TestError.commandTimeout(command: command, timeout: timeout)
        }
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        
        let output = String(data: outputData, encoding: .utf8) ?? ""
        let error = String(data: errorData, encoding: .utf8) ?? ""
        
        return CommandResult(exitCode: process.terminationStatus, output: output, error: error)
    }
    
    /// Execute a command that should succeed
    @discardableResult
    static func runSuccessfulCommand(_ command: String, arguments: [String] = []) throws -> CommandResult {
        let result = try runCommand(command, arguments: arguments)
        if !result.success {
            throw TestError.commandFailed(command: command, exitCode: result.exitCode, output: result.output, error: result.error)
        }
        return result
    }
    
    /// Execute a command that should fail
    @discardableResult
    static func runFailingCommand(_ command: String, arguments: [String] = []) throws -> CommandResult {
        let result = try runCommand(command, arguments: arguments)
        if result.success {
            throw TestError.commandUnexpectedSuccess(command: command, output: result.output)
        }
        return result
    }
    
    // MARK: - File System Helpers
    
    /// Create a temporary test file with specified content
    static func createTestFile(name: String, content: String = "// Test file\n", in directory: String = "Tests/xcodeproj-cliTests/TestResources") throws -> URL {
        let fileURL = URL(fileURLWithPath: directory).appendingPathComponent(name)
        
        // Create directory if needed
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
    
    /// Create a temporary test directory with files
    static func createTestDirectory(name: String, files: [String: String] = [:], in directory: String = "Tests/xcodeproj-cliTests/TestResources") throws -> URL {
        let dirURL = URL(fileURLWithPath: directory).appendingPathComponent(name)
        
        try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true, attributes: nil)
        
        for (fileName, content) in files {
            let fileURL = dirURL.appendingPathComponent(fileName)
            
            // Create intermediate directories if needed
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )
            
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        }
        
        return dirURL
    }
    
    /// Clean up temporary test files and directories
    static func cleanupTestItems(_ paths: [URL]) {
        for path in paths {
            try? FileManager.default.removeItem(at: path)
        }
    }
    
    // MARK: - Assertion Helpers
    
    /// Assert that command output contains expected text
    static func assertOutputContains(_ output: String, _ expectedText: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(
            output.contains(expectedText),
            "Expected output to contain '\(expectedText)' but got: \(output)",
            file: file,
            line: line
        )
    }
    
    /// Assert that command output does not contain text
    static func assertOutputDoesNotContain(_ output: String, _ unwantedText: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(
            output.contains(unwantedText),
            "Expected output NOT to contain '\(unwantedText)' but got: \(output)",
            file: file,
            line: line
        )
    }
    
    /// Assert command completed successfully
    static func assertCommandSuccess(_ result: CommandResult, message: String = "", file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(
            result.success,
            "Command failed with exit code \(result.exitCode). \(message)\nOutput: \(result.output)\nError: \(result.error)",
            file: file,
            line: line
        )
    }
    
    /// Assert command failed as expected
    static func assertCommandFailure(_ result: CommandResult, message: String = "", file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(
            result.success,
            "Command unexpectedly succeeded. \(message)\nOutput: \(result.output)",
            file: file,
            line: line
        )
    }
    
    /// Assert that either output or error contains expected text (more flexible for CLI error handling)
    static func assertOutputOrErrorContains(_ result: CommandResult, _ expectedText: String, file: StaticString = #filePath, line: UInt = #line) {
        // For ArgumentParser, "required" messages appear as "Missing expected argument"
        let alternativeTexts = expectedText == "required" ?
            ["required", "Missing expected argument", "missing"] :
            [expectedText]

        let found = alternativeTexts.contains { text in
            result.output.contains(text) || result.error.contains(text)
        }

        XCTAssertTrue(
            found,
            "Expected output or error to contain '\(expectedText)' (or alternatives: \(alternativeTexts)) but got output: \(result.output) error: \(result.error)",
            file: file,
            line: line
        )
    }
    
    // MARK: - Private Helpers
    
    private static var productsDirectory: URL {
        #if os(macOS)
        for bundle in Bundle.allBundles where bundle.bundlePath.hasSuffix(".xctest") {
            return bundle.bundleURL.deletingLastPathComponent()
        }
        fatalError("couldn't find the products directory")
        #else
        return Bundle.main.bundleURL
        #endif
    }
}

// MARK: - Test Errors

enum TestError: Error, LocalizedError {
    case commandTimeout(command: String, timeout: TimeInterval)
    case commandFailed(command: String, exitCode: Int32, output: String, error: String)
    case commandUnexpectedSuccess(command: String, output: String)
    case testSetupFailure(String)
    case testCleanupFailure(String)
    
    var errorDescription: String? {
        switch self {
        case .commandTimeout(let command, let timeout):
            return "Command '\(command)' timed out after \(timeout) seconds"
        case .commandFailed(let command, let exitCode, let output, let error):
            return "Command '\(command)' failed with exit code \(exitCode). Output: \(output) Error: \(error)"
        case .commandUnexpectedSuccess(let command, let output):
            return "Command '\(command)' unexpectedly succeeded. Output: \(output)"
        case .testSetupFailure(let message):
            return "Test setup failed: \(message)"
        case .testCleanupFailure(let message):
            return "Test cleanup failed: \(message)"
        }
    }
}

// MARK: - Base Test Class

/// Base class for xcodeproj-cli tests providing common functionality
class XCTProjectTestCase: XCTestCase {
    
    override func setUp() {
        super.setUp()
        
        do {
            try TestHelpers.backupTestProject()
        } catch {
            XCTFail("Failed to backup test project: \(error)")
        }
    }
    
    override func tearDown() {
        do {
            try TestHelpers.restoreTestProject()
        } catch {
            XCTFail("Failed to restore test project: \(error)")
        }
        
        super.tearDown()
    }
    
    // Convenience methods for subclasses
    
    @discardableResult
    func runCommand(_ command: String, arguments: [String] = []) throws -> TestHelpers.CommandResult {
        return try TestHelpers.runCommand(command, arguments: arguments)
    }
    
    @discardableResult
    func runSuccessfulCommand(_ command: String, arguments: [String] = []) throws -> TestHelpers.CommandResult {
        return try TestHelpers.runSuccessfulCommand(command, arguments: arguments)
    }
    
    @discardableResult
    func runFailingCommand(_ command: String, arguments: [String] = []) throws -> TestHelpers.CommandResult {
        return try TestHelpers.runFailingCommand(command, arguments: arguments)
    }
}