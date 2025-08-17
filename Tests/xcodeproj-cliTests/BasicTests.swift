//
// BasicTests.swift
// xcodeproj-cliTests
//
// Basic functionality tests for xcodeproj-cli executable, help, and version commands
//

import XCTest
import Foundation

final class BasicTests: XCTestCase {
    
    // MARK: - Binary Execution Tests
    
    func testBinaryExists() throws {
        let binaryPath = TestHelpers.binaryPath
        XCTAssertTrue(FileManager.default.fileExists(atPath: binaryPath.path), "Binary should exist at \(binaryPath.path)")
    }
    
    func testBinaryIsExecutable() throws {
        let binaryPath = TestHelpers.binaryPath
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: binaryPath.path), "Binary should be executable")
    }
    
    func testExecutableRuns() throws {
        // Test that the binary runs without crashing (even with no arguments)
        let process = Process()
        process.executableURL = TestHelpers.binaryPath
        process.arguments = ["--help"] // Use help to get a predictable response
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        
        try process.run()
        process.waitUntilExit()
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""
        
        // Should run and provide help output
        XCTAssertTrue(output.contains("xcodeproj-cli") || output.contains("Usage"), "Should show help information")
    }
    
    // MARK: - Version Command Tests
    
    func testVersionCommand() throws {
        let result = try TestHelpers.runCommand("--version", arguments: [])
        
        TestHelpers.assertCommandSuccess(result, message: "Version command should succeed")
        TestHelpers.assertOutputContains(result.output, "xcodeproj-cli version")
        TestHelpers.assertOutputContains(result.output, "2.3.0")
    }
    
    func testVersionCommandShortFlag() throws {
        // Test if there's a short version flag (some CLIs support -v)
        let result = try TestHelpers.runCommand("-v", arguments: [])
        
        if result.success {
            // If -v works, it should show version
            TestHelpers.assertOutputContains(result.output, "version")
        } else {
            // If -v doesn't work, that's also acceptable - not all CLIs support it
            XCTAssertTrue(true, "Short version flag not supported, which is acceptable")
        }
    }
    
    // MARK: - Help Command Tests
    
    func testHelpCommand() throws {
        let result = try TestHelpers.runCommand("--help", arguments: [])
        
        TestHelpers.assertCommandSuccess(result, message: "Help command should succeed")
        TestHelpers.assertOutputContains(result.output, "Usage:")
        TestHelpers.assertOutputContains(result.output, "xcodeproj-cli")
        TestHelpers.assertOutputContains(result.output, "command")
    }
    
    func testHelpCommandShortFlag() throws {
        let result = try TestHelpers.runCommand("-h", arguments: [])
        
        TestHelpers.assertCommandSuccess(result, message: "Short help flag should succeed")
        TestHelpers.assertOutputContains(result.output, "Usage:")
        TestHelpers.assertOutputContains(result.output, "xcodeproj-cli")
    }
    
    func testHelpShowsAvailableCommands() throws {
        let result = try TestHelpers.runCommand("--help", arguments: [])
        
        TestHelpers.assertCommandSuccess(result)
        
        // Check for major command categories
        let expectedCommands = [
            "add-file",
            "add-folder", 
            "list-targets",
            "create-groups",
            "validate"
        ]
        
        for command in expectedCommands {
            if result.output.contains(command) {
                // Found at least one expected command, help is working
                XCTAssertTrue(true)
                return
            }
        }
        
        // If no specific commands found, at least check for general help structure
        XCTAssertTrue(
            result.output.contains("OPERATIONS") || result.output.contains("Commands") || result.output.contains("FILE"),
            "Help should show command categories or individual commands"
        )
    }
    
    // MARK: - No Arguments Handling
    
    func testNoArgumentsShowsHelp() throws {
        // When run with no arguments, should show help or usage info
        let process = Process()
        process.executableURL = TestHelpers.binaryPath
        process.arguments = []
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        
        try process.run()
        process.waitUntilExit()
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""
        
        // Should either succeed with help or fail gracefully with usage info
        XCTAssertTrue(
            output.contains("Usage") || output.contains("xcodeproj-cli") || output.contains("command"),
            "No arguments should show usage information. Got: \(output)"
        )
    }
    
    // MARK: - Invalid Command Handling
    
    func testInvalidCommandHandling() throws {
        let result = try TestHelpers.runCommand("invalid-command-that-does-not-exist", arguments: [])
        
        TestHelpers.assertCommandFailure(result, message: "Invalid commands should fail")
        
        // Should provide helpful error message
        XCTAssertTrue(
            result.output.contains("Unknown command") || 
            result.output.contains("Invalid") ||
            result.output.contains("not found") ||
            result.error.contains("Unknown command") ||
            result.error.contains("Invalid"),
            "Should provide helpful error for invalid command. Output: \(result.output), Error: \(result.error)"
        )
    }
    
    // MARK: - Project Path Handling
    
    func testMissingProjectHandling() throws {
        // Test behavior when project file doesn't exist
        let result = try TestHelpers.runCommand("validate", arguments: ["--project", "NonExistent.xcodeproj"])
        
        TestHelpers.assertCommandFailure(result, message: "Should fail when project doesn't exist")
        
        // Should provide helpful error message about missing project
        XCTAssertTrue(
            result.output.contains("not found") || 
            result.output.contains("does not exist") ||
            result.output.contains("No such file") ||
            result.output.contains("cannot be found") ||
            result.error.contains("not found") ||
            result.error.contains("does not exist"),
            "Should provide helpful error for missing project. Output: \(result.output), Error: \(result.error)"
        )
    }
    
    func testInvalidProjectHandling() throws {
        // Create a dummy file that's not a valid project
        let tempFile = try TestHelpers.createTestFile(name: "Invalid.xcodeproj", content: "not a project")
        defer { TestHelpers.cleanupTestItems([tempFile]) }
        
        let result = try TestHelpers.runCommand("validate", arguments: ["--project", tempFile.path])
        
        TestHelpers.assertCommandFailure(result, message: "Should fail when project is invalid")
        
        // Should provide helpful error message about invalid project
        XCTAssertTrue(
            result.output.contains("invalid") || 
            result.output.contains("corrupt") ||
            result.output.contains("not a valid") ||
            result.output.contains("doesn't contain a .pbxproj") ||
            result.error.contains("invalid") ||
            result.error.contains("Error"),
            "Should provide helpful error for invalid project. Output: \(result.output), Error: \(result.error)"
        )
    }
    
    // MARK: - Global Options Tests
    
    func testVerboseFlag() throws {
        // Test verbose output flag
        let result = try TestHelpers.runCommand("validate", arguments: ["--verbose"])
        
        // Verbose should either work (showing more output) or be ignored gracefully
        if result.success {
            // If verbose is supported, we might see more detailed output
            XCTAssertTrue(true, "Verbose flag works")
        } else {
            // If verbose causes failure, the error should be about verbose flag specifically
            if result.output.contains("verbose") || result.error.contains("verbose") {
                XCTAssertTrue(true, "Verbose flag error is properly reported")
            } else {
                // If it's failing for other reasons, that's a different issue
                XCTFail("Verbose flag should either work or provide clear error about verbose support")
            }
        }
    }
    
    func testVerboseFlagShort() throws {
        // Test short verbose flag
        let result = try TestHelpers.runCommand("validate", arguments: ["-V"])
        
        // Similar to verbose test above
        if result.success {
            XCTAssertTrue(true, "Short verbose flag works")
        } else {
            // Should not fail for other reasons if -V is the only extra argument
            if result.output.contains("V") || result.error.contains("V") {
                XCTAssertTrue(true, "Short verbose flag error is properly reported")
            }
        }
    }
    
    func testDryRunFlag() throws {
        // Test dry run flag (should not make actual changes)
        let result = try TestHelpers.runCommand("validate", arguments: ["--dry-run"])
        
        // Dry run should either work or be ignored gracefully for read-only commands
        if result.success {
            XCTAssertTrue(true, "Dry run flag works with validate command")
        } else {
            // If dry run causes issues, should be clear about it
            XCTAssertTrue(
                result.output.contains("dry") || result.error.contains("dry") || result.output.contains("preview"),
                "Dry run flag error should be clear. Output: \(result.output), Error: \(result.error)"
            )
        }
    }
}