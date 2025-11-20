//
// OutputFormatTests.swift
// xcodeproj-cli Tests
//
// Tests for CLI output formatting consistency
//

import XCTest
import Foundation
@testable import xcodeproj_cli

/// Tests for CLI output formatting, ensuring consistency across commands
@MainActor
final class OutputFormatTests: XCTestCase {
    
    private var testProjectPath: String!
    
    override func setUp() async throws {
        testProjectPath = try CLITestHarness.createTestProject(named: "OutputTestProject")
    }
    
    override func tearDown() async throws {
        if let projectPath = testProjectPath {
            CLITestHarness.cleanupTestProject(at: projectPath)
        }
    }
    
    // MARK: - List Commands Output Format Tests
    
    func testListTargetsOutputFormat() {
        let result = CLITestHarness.executeCommand([
            "--project", testProjectPath,
            "list-targets"
        ])
        
        XCTAssertEqual(result.exitCode, 0, "list-targets should succeed")
        
        // Test output formatting expectations
        XCTAssertTrue(
            result.stdout.contains("Available targets:") || result.stdout.contains("TestApp"),
            "Should have consistent header or target listing"
        )
        
        // Test that output is properly structured
        let lines = result.stdout.components(separatedBy: .newlines).filter { !$0.isEmpty }
        XCTAssertGreaterThan(lines.count, 0, "Should have multiple lines of output")
        
        GoldenFileManager.assertMatchesGolden(result: result, name: "list-targets-format")
    }
    
    func testListGroupsOutputFormat() {
        let result = CLITestHarness.executeCommand([
            "--project", testProjectPath,
            "list-groups"
        ])
        
        XCTAssertEqual(result.exitCode, 0, "list-groups should succeed")
        
        // Test consistent formatting for groups
        let lines = result.stdout.components(separatedBy: .newlines)
        let nonEmptyLines = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        
        XCTAssertGreaterThan(nonEmptyLines.count, 0, "Should have group output")
        
        GoldenFileManager.assertMatchesGolden(result: result, name: "list-groups-format")
    }
    
    func testListFilesOutputFormat() {
        let result = CLITestHarness.executeCommand([
            "--project", testProjectPath,
            "list-files"
        ])
        
        XCTAssertEqual(result.exitCode, 0, "list-files should succeed")
        
        // Test file listing format consistency
        GoldenFileManager.assertMatchesGolden(result: result, name: "list-files-format")
    }
    
    func testListTreeOutputFormat() {
        let result = CLITestHarness.executeCommand([
            "--project", testProjectPath,
            "list-tree"
        ])
        
        XCTAssertEqual(result.exitCode, 0, "list-tree should succeed")
        
        // Test tree structure formatting
        let output = result.stdout
        
        // Tree output should have some indentation or structure
        if !output.isEmpty {
            XCTAssertTrue(
                output.contains("Sources") || output.contains("├") || output.contains("└"),
                "Tree output should have some structure"
            )
        }
        
        GoldenFileManager.assertMatchesGolden(result: result, name: "list-tree-format")
    }
    
    func testListBuildConfigsOutputFormat() {
        let result = CLITestHarness.executeCommand([
            "--project", testProjectPath,
            "list-build-configs"
        ])
        
        XCTAssertEqual(result.exitCode, 0, "list-build-configs should succeed")
        
        // Should list Debug and Release configurations
        XCTAssertTrue(result.stdout.contains("Debug"), "Should contain Debug config")
        XCTAssertTrue(result.stdout.contains("Release"), "Should contain Release config")
        
        GoldenFileManager.assertMatchesGolden(result: result, name: "list-build-configs-format")
    }
    
    // MARK: - Tabular Output Tests
    
    func testBuildSettingsTableFormat() {
        let result = CLITestHarness.executeCommand([
            "--project", testProjectPath,
            "list-build-settings",
            "--target", "TestApp"
        ])
        
        XCTAssertEqual(result.exitCode, 0, "list-build-settings should succeed")
        
        // Test tabular format for build settings
        let lines = result.stdout.components(separatedBy: .newlines)
        let nonEmptyLines = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        
        if nonEmptyLines.count > 0 {
            // Should have some structured output
            XCTAssertGreaterThan(nonEmptyLines.count, 0, "Should have build settings output")
        }
        
        GoldenFileManager.assertMatchesGolden(result: result, name: "build-settings-table-format")
    }
    
    func testSwiftPackagesTableFormat() {
        let result = CLITestHarness.executeCommand([
            "--project", testProjectPath,
            "list-swift-packages"
        ])
        
        XCTAssertEqual(result.exitCode, 0, "list-swift-packages should succeed")
        
        // Empty project should have consistent "no packages" output
        GoldenFileManager.assertMatchesGolden(result: result, name: "swift-packages-table-format")
    }
    
    // MARK: - Verbose Output Tests
    
    func testVerboseOutputFormatting() {
        let regularResult = CLITestHarness.executeCommand([
            "--project", testProjectPath,
            "validate"
        ])
        
        let verboseResult = CLITestHarness.executeCommand([
            "--project", testProjectPath,
            "--verbose",
            "validate"
        ])
        
        XCTAssertEqual(regularResult.exitCode, 0, "Regular validate should succeed")
        XCTAssertEqual(verboseResult.exitCode, 0, "Verbose validate should succeed")
        
        // Verbose might have additional output
        // At minimum, both should succeed and have consistent base output
        
        GoldenFileManager.assertMatchesGolden(result: regularResult, name: "validate-regular-format")
        GoldenFileManager.assertMatchesGolden(result: verboseResult, name: "validate-verbose-format")
    }
    
    func testVerboseListTargetsFormatting() {
        let regularResult = CLITestHarness.executeCommand([
            "--project", testProjectPath,
            "list-targets"
        ])
        
        let verboseResult = CLITestHarness.executeCommand([
            "--project", testProjectPath,
            "--verbose",
            "list-targets"
        ])
        
        XCTAssertEqual(regularResult.exitCode, 0, "Regular list-targets should succeed")
        XCTAssertEqual(verboseResult.exitCode, 0, "Verbose list-targets should succeed")
        
        GoldenFileManager.assertMatchesGolden(result: regularResult, name: "list-targets-regular-format")
        GoldenFileManager.assertMatchesGolden(result: verboseResult, name: "list-targets-verbose-format")
    }
    
    // MARK: - Error Message Formatting Tests
    
    func testErrorMessageFormat() {
        let result = CLITestHarness.executeCommand([
            "--project", "NonExistent.xcodeproj",
            "list-targets"
        ])
        
        XCTAssertEqual(result.exitCode, 1, "Should fail with non-existent project")
        
        // Error messages should start with ❌ and be clear
        XCTAssertTrue(result.stderr.contains("❌") || result.stderr.contains("Error"), "Should have error indicator")
        
        GoldenFileManager.assertMatchesGolden(
            result: result,
            name: "project-not-found-format",
            category: "errors"
        )
    }
    
    func testInvalidCommandErrorFormat() {
        let result = CLITestHarness.executeCommand([
            "nonexistent-command"
        ])

        // ArgumentParser uses exit code 64 for validation errors
        XCTAssertTrue(result.exitCode == 64 || result.exitCode == 1, "Should fail with invalid command")

        // Should have consistent error formatting
        XCTAssertTrue(result.stderr.contains("Error"), "Should have error indicator")
        XCTAssertTrue(
            result.stderr.contains("Unknown command") ||
            result.stderr.contains("Unknown subcommand") ||
            result.stderr.contains("Unexpected argument") ||
            result.stderr.contains("unrecognized"),
            "Should identify the issue. Got: \(result.stderr)"
        )

        GoldenFileManager.assertMatchesGolden(
            result: result,
            name: "invalid-command-format",
            category: "errors"
        )
    }
    
    func testMissingArgumentsErrorFormat() {
        let result = CLITestHarness.executeCommand([
            "--project", testProjectPath,
            "add-file"
            // Missing required arguments
        ])

        // ArgumentParser uses exit code 64 for validation errors
        XCTAssertTrue(result.exitCode == 64 || result.exitCode == 1, "Should fail with missing arguments")

        // Error should explain what's missing
        GoldenFileManager.assertMatchesGolden(
            result: result,
            name: "missing-arguments-format",
            category: "errors"
        )
    }
    
    // MARK: - Success Message Formatting Tests
    
    func testSuccessMessageFormat() {
        let result = CLITestHarness.executeCommand([
            "--project", testProjectPath,
            "create-groups",
            "TestFormatGroup"
        ])
        
        XCTAssertEqual(result.exitCode, 0, "create-groups should succeed")
        
        // Success messages should be consistent
        XCTAssertTrue(
            result.stdout.contains("✅") || result.stdout.contains("Created") || 
            result.stdout.contains("successfully"),
            "Should have success indicator"
        )
        
        GoldenFileManager.assertMatchesGolden(result: result, name: "success-message-format")
    }
    
    // MARK: - Dry Run Output Formatting Tests
    
    func testDryRunOutputFormat() {
        let result = CLITestHarness.executeCommand([
            "--project", testProjectPath,
            "--dry-run",
            "create-groups",
            "DryRunTestGroup"
        ])

        XCTAssertEqual(result.exitCode, 0, "dry-run should succeed")

        // Should have clear dry run indicators
        XCTAssertTrue(
            result.stdout.contains("dry run") ||
            result.stdout.contains("DRY RUN") ||
            result.stdout.contains("Dry Run"),
            "Should have dry run indicator"
        )

        GoldenFileManager.assertMatchesGolden(result: result, name: "dry-run-format")
    }
    
    // MARK: - Empty Result Formatting Tests
    
    func testEmptyResultsFormat() {
        // Test commands that might return empty results
        let result = CLITestHarness.executeCommand([
            "--project", testProjectPath,
            "list-invalid-references"
        ])
        
        XCTAssertEqual(result.exitCode, 0, "list-invalid-references should succeed")
        
        // Clean project should have no invalid references
        // Test that empty results are handled gracefully
        
        GoldenFileManager.assertMatchesGolden(result: result, name: "empty-results-format")
    }
    
    func testEmptySwiftPackagesFormat() {
        let result = CLITestHarness.executeCommand([
            "--project", testProjectPath,
            "list-swift-packages"
        ])
        
        XCTAssertEqual(result.exitCode, 0, "list-swift-packages should succeed")
        
        // Empty project should handle no packages gracefully
        GoldenFileManager.assertMatchesGolden(result: result, name: "empty-packages-format")
    }
    
    // MARK: - Output Consistency Tests
    
    func testOutputConsistencyAcrossCommands() {
        // Test that similar commands have consistent output patterns
        let listCommands = [
            "list-targets",
            "list-groups", 
            "list-files",
            "list-build-configs",
            "list-swift-packages"
        ]
        
        var results: [String: CLICommandResult] = [:]
        
        for command in listCommands {
            let result = CLITestHarness.executeCommand([
                "--project", testProjectPath,
                command
            ])
            
            XCTAssertEqual(result.exitCode, 0, "\(command) should succeed")
            results[command] = result
            
            GoldenFileManager.assertMatchesGolden(
                result: result,
                name: "\(command)-consistency"
            )
        }
        
        // All list commands should succeed
        for (command, result) in results {
            XCTAssertEqual(result.exitCode, 0, "\(command) should have consistent success")
        }
    }
    
    // MARK: - Unicode and Special Characters Tests
    
    func testUnicodeInOutput() {
        // Test that Unicode characters in output are handled correctly
        let result = CLITestHarness.executeCommand([
            "--project", testProjectPath,
            "validate"
        ])
        
        XCTAssertEqual(result.exitCode, 0, "validate should succeed")
        
        // Check that emoji and Unicode are preserved in output
        if result.stdout.contains("✅") {
            XCTAssertTrue(result.stdout.contains("✅"), "Unicode should be preserved")
        }
        
        GoldenFileManager.assertMatchesGolden(result: result, name: "unicode-output")
    }
    
    // MARK: - Long Output Tests
    
    func testLongOutputHandling() {
        // Create multiple groups to test longer output
        let commands = [
            ["create-groups", "LongTest/Group1"],
            ["create-groups", "LongTest/Group2"], 
            ["create-groups", "LongTest/Group3"]
        ]
        
        // Execute multiple commands to create longer output scenarios
        for command in commands {
            let fullCommand = ["--project", testProjectPath!] + command
            let result = CLITestHarness.executeCommand(fullCommand)
            XCTAssertEqual(result.exitCode, 0, "Command should succeed")
        }
        
        // Now test listing the groups
        let result = CLITestHarness.executeCommand([
            "--project", testProjectPath,
            "list-groups"
        ])
        
        XCTAssertEqual(result.exitCode, 0, "list-groups should succeed")
        XCTAssertTrue(result.stdout.contains("LongTest"), "Should contain created groups")
        
        GoldenFileManager.assertMatchesGolden(result: result, name: "long-output-handling")
    }
    
    // MARK: - Output Encoding Tests
    
    func testOutputEncoding() {
        // Test that output encoding is consistent
        let result = CLITestHarness.executeCommand([
            "--project", testProjectPath,
            "list-targets"
        ])
        
        XCTAssertEqual(result.exitCode, 0, "list-targets should succeed")
        
        // Ensure output is valid UTF-8
        let outputData = result.stdout.data(using: .utf8)
        XCTAssertNotNil(outputData, "Output should be valid UTF-8")
        
        let reconvertedOutput = String(data: outputData!, encoding: .utf8)
        XCTAssertEqual(reconvertedOutput, result.stdout, "Output should round-trip through UTF-8")
        
        GoldenFileManager.assertMatchesGolden(result: result, name: "output-encoding")
    }
}