//
// CLITestHarnessVerificationTests.swift
// xcodeproj-cli Tests
//
// Simple tests to verify CLITestHarness functionality
//

import XCTest
import Foundation
@testable import xcodeproj_cli

/// Simple tests to verify the CLITestHarness works correctly
@MainActor
final class CLITestHarnessVerificationTests: XCTestCase {
    
    // MARK: - Basic Functionality Tests
    
    func testVersionCommand() {
        let result = CLITestHarness.executeCommand(["--version"])
        
        XCTAssertEqual(result.exitCode, 0, "Version command should succeed")
        XCTAssertFalse(result.stdout.isEmpty, "Version should produce output")
        XCTAssertTrue(result.stderr.isEmpty, "Version should not produce stderr")
        
        print("Version output: \(result.stdout)")
    }
    
    func testVersionCommandShortForm() {
        let result = CLITestHarness.executeCommand(["-v"])

        // ArgumentParser doesn't support -v for version (exit code 64)
        XCTAssertEqual(result.exitCode, 64, "-v is not supported, should exit with 64")
        XCTAssertFalse(result.stderr.isEmpty, "Should produce error message")
        XCTAssertTrue(
            result.stderr.contains("Unknown option"),
            "Should report unknown option"
        )

        print("Version output (short): \(result.stderr)")
    }
    
    func testHelpCommand() {
        let result = CLITestHarness.executeCommand(["--help"])
        
        XCTAssertEqual(result.exitCode, 0, "Help command should succeed")
        XCTAssertFalse(result.stdout.isEmpty, "Help should produce output")
        XCTAssertTrue(result.stderr.isEmpty, "Help should not produce stderr")
        
        print("Help output length: \(result.stdout.count) characters")
    }
    
    func testHelpCommandShortForm() {
        let result = CLITestHarness.executeCommand(["-h"])
        
        XCTAssertEqual(result.exitCode, 0, "Short help command should succeed")
        XCTAssertFalse(result.stdout.isEmpty, "Help should produce output")
        XCTAssertTrue(result.stderr.isEmpty, "Help should not produce stderr")
        
        print("Help output (short) length: \(result.stdout.count) characters")
    }
    
    func testEmptyCommand() {
        let result = CLITestHarness.executeCommand([])
        
        XCTAssertEqual(result.exitCode, 0, "Empty command should show help")
        XCTAssertFalse(result.stdout.isEmpty, "Empty command should produce help output")
        XCTAssertTrue(result.stderr.isEmpty, "Empty command should not produce stderr")
        
        print("Empty command output length: \(result.stdout.count) characters")
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidCommand() {
        let result = CLITestHarness.executeCommand(["invalid-command"])

        // ArgumentParser returns exit code 64 for validation errors
        XCTAssert(result.exitCode == 1 || result.exitCode == 64, "Invalid command should fail")
        XCTAssertFalse(result.stderr.isEmpty, "Should produce error message")

        print("Invalid command error: \(result.stderr)")
    }
    
    func testInvalidFlag() {
        let result = CLITestHarness.executeCommand(["--invalid-flag"])

        // ArgumentParser returns exit code 64 for validation errors
        XCTAssert(result.exitCode == 1 || result.exitCode == 64, "Invalid flag should fail")
        XCTAssertFalse(result.stderr.isEmpty, "Should produce error message")

        print("Invalid flag error: \(result.stderr)")
    }
    
    // MARK: - Command Help Tests
    
    func testCommandSpecificHelp() {
        let result = CLITestHarness.executeCommand(["list-targets", "--help"])
        
        XCTAssertEqual(result.exitCode, 0, "Command help should succeed")
        XCTAssertFalse(result.stdout.isEmpty, "Should produce help output")
        XCTAssertTrue(result.stderr.isEmpty, "Should not produce stderr")
        
        print("Command help output length: \(result.stdout.count) characters")
    }
    
    // MARK: - Performance Tests
    
    func testCommandExecutionSpeed() {
        let startTime = Date()
        
        let result = CLITestHarness.executeCommand(["--version"])
        
        let executionTime = Date().timeIntervalSince(startTime)
        
        XCTAssertEqual(result.exitCode, 0, "Version command should succeed")
        XCTAssertLessThan(executionTime, 5.0, "Command should complete within 5 seconds")
        
        print("Version command execution time: \(executionTime) seconds")
    }
    
    func testMultipleCommandsInSequence() {
        let commands = [
            ["--version"],
            ["--help"],
            ["list-targets", "--help"],
            ["validate", "--help"]
        ]
        
        for (index, command) in commands.enumerated() {
            let startTime = Date()
            let result = CLITestHarness.executeCommand(command)
            let executionTime = Date().timeIntervalSince(startTime)
            
            XCTAssertEqual(result.exitCode, 0, "Command \(index + 1) should succeed")
            XCTAssertLessThan(executionTime, 5.0, "Command \(index + 1) should complete within 5 seconds")
            
            print("Command \(index + 1) (\(command.joined(separator: " "))) execution time: \(executionTime) seconds")
        }
    }
    
    // MARK: - CLIResult Structure Tests
    
    func testCLIResultProperties() {
        let result = CLITestHarness.executeCommand(["--version"])

        XCTAssertEqual(result.exitCode, 0, "Exit code should be 0")
        XCTAssertTrue(result.success, "success should be true for exit code 0")
        XCTAssertFalse(result.stdout.isEmpty, "stdout should not be empty")
        XCTAssertTrue(result.stderr.isEmpty, "stderr should be empty for success")
    }

    func testCLIResultPropertiesWithError() {
        let result = CLITestHarness.executeCommand(["invalid-command"])

        // ArgumentParser returns exit code 64 for validation errors
        XCTAssert(result.exitCode == 1 || result.exitCode == 64, "Exit code should be non-zero")
        XCTAssertFalse(result.success, "success should be false for failure")
        XCTAssertFalse(result.stderr.isEmpty, "stderr should not be empty for error")
    }
}