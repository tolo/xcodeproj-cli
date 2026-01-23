//
// ArgumentParsingTests.swift
// xcodeproj-cli Tests
//
// Tests for CLI argument parsing behavior
//

import XCTest
import Foundation
@testable import xcodeproj_cli

/// Tests for CLI argument parsing, global flags, and error handling
@MainActor
final class ArgumentParsingTests: XCTestCase {
    
    private var testProjectPath: String!
    
    override func setUp() async throws {
        testProjectPath = try CLITestHarness.createTestProject(named: "ArgumentTestProject")
    }
    
    override func tearDown() async throws {
        if let projectPath = testProjectPath {
            CLITestHarness.cleanupTestProject(at: projectPath)
        }
    }
    
    // MARK: - Global Options Tests
    
    func testProjectFlagLongForm() {
        let result = CLITestHarness.executeCommand([
            "--project", testProjectPath,
            "list-targets"
        ])
        
        XCTAssertEqual(result.exitCode, 0, "--project flag should work")
        XCTAssertTrue(result.stdout.contains("TestApp"), "Should list targets from specified project")
        
        GoldenFileManager.assertMatchesGolden(result: result, name: "project-flag-long")
    }
    
    func testProjectFlagShortForm() {
        let result = CLITestHarness.executeCommand([
            "-p", testProjectPath,
            "list-targets"
        ])
        
        XCTAssertEqual(result.exitCode, 0, "-p flag should work")
        XCTAssertTrue(result.stdout.contains("TestApp"), "Should list targets from specified project")
        
        GoldenFileManager.assertMatchesGolden(result: result, name: "project-flag-short")
    }
    
    func testVerboseFlagLongForm() {
        let result = CLITestHarness.executeCommand([
            "--project", testProjectPath,
            "--verbose",
            "validate"
        ])
        
        XCTAssertEqual(result.exitCode, 0, "--verbose flag should work")
        
        GoldenFileManager.assertMatchesGolden(result: result, name: "verbose-flag-long")
    }
    
    func testVerboseFlagShortForm() {
        let result = CLITestHarness.executeCommand([
            "--project", testProjectPath,
            "-V",
            "validate"
        ])
        
        XCTAssertEqual(result.exitCode, 0, "-V flag should work")
        
        GoldenFileManager.assertMatchesGolden(result: result, name: "verbose-flag-short")
    }
    
    func testDryRunFlag() {
        let result = CLITestHarness.executeCommand([
            "--project", testProjectPath,
            "--dry-run",
            "create-groups",
            "TestGroup"
        ])
        
        XCTAssertEqual(result.exitCode, 0, "--dry-run flag should work")
        XCTAssertTrue(result.stdout.contains("DRY RUN"), "Should indicate dry run mode")
        
        GoldenFileManager.assertMatchesGolden(result: result, name: "dry-run-flag")
    }
    
    func testVersionFlagLongForm() {
        let result = CLITestHarness.executeCommand(["--version"])
        
        XCTAssertEqual(result.exitCode, 0, "--version should work")
        XCTAssertFalse(result.stdout.isEmpty, "Should display version information")
        
        GoldenFileManager.assertMatchesGolden(result: result, name: "version-flag-long")
    }
    
    func testVersionFlagShortForm() {
        let result = CLITestHarness.executeCommand(["-v"])

        // ArgumentParser doesn't support -v for version (conflicts with other short flags)
        XCTAssert(result.exitCode == 64, "-v is not supported and should fail with exit code 64")
        XCTAssertTrue(
            result.stderr.contains("Unknown option") || result.stderr.contains("Unknown flag"),
            "Should report unknown option"
        )

        GoldenFileManager.assertMatchesGolden(result: result, name: "version-flag-short")
    }
    
    func testHelpFlagLongForm() {
        let result = CLITestHarness.executeCommand(["--help"])

        XCTAssertEqual(result.exitCode, 0, "--help should work")
        XCTAssertTrue(
            result.stdout.contains("USAGE") || result.stdout.contains("Usage") || result.stdout.contains("usage"),
            "Should display usage information"
        )

        GoldenFileManager.assertMatchesGolden(result: result, name: "help-flag-long")
    }
    
    func testHelpFlagShortForm() {
        let result = CLITestHarness.executeCommand(["-h"])

        XCTAssertEqual(result.exitCode, 0, "-h should work for help")
        XCTAssertTrue(
            result.stdout.contains("USAGE") || result.stdout.contains("Usage") || result.stdout.contains("usage"),
            "Should display usage information"
        )

        GoldenFileManager.assertMatchesGolden(result: result, name: "help-flag-short")
    }
    
    // MARK: - Argument Order Tests
    
    func testGlobalFlagsBeforeCommand() {
        let result = CLITestHarness.executeCommand([
            "--project", testProjectPath,
            "--verbose",
            "list-targets"
        ])
        
        XCTAssertEqual(result.exitCode, 0, "Global flags before command should work")
        
        GoldenFileManager.assertMatchesGolden(result: result, name: "flags-before-command")
    }
    
    func testGlobalFlagsAfterCommand() {
        // Note: Current implementation might not support this, but we test to document behavior
        let result = CLITestHarness.executeCommand([
            "list-targets",
            "--project", testProjectPath,
            "--verbose"
        ])
        
        // This might fail with current implementation - that's okay, we're documenting behavior
        GoldenFileManager.assertMatchesGolden(result: result, name: "flags-after-command")
    }
    
    func testMixedFlagOrder() {
        let result = CLITestHarness.executeCommand([
            "--verbose",
            "--project", testProjectPath,
            "list-targets"
        ])
        
        XCTAssertEqual(result.exitCode, 0, "Mixed flag order should work")
        
        GoldenFileManager.assertMatchesGolden(result: result, name: "mixed-flag-order")
    }
    
    // MARK: - Command-Specific Flag Tests
    
    func testCommandSpecificFlags() {
        let result = CLITestHarness.executeCommand([
            "--project", testProjectPath,
            "list-build-settings",
            "--target", "TestApp",
            "--config", "Debug"
        ])
        
        XCTAssertEqual(result.exitCode, 0, "Command-specific flags should work")
        
        GoldenFileManager.assertMatchesGolden(result: result, name: "command-specific-flags")
    }
    
    func testCommandSpecificFlagsShortForm() {
        let result = CLITestHarness.executeCommand([
            "--project", testProjectPath,
            "list-build-settings",
            "-t", "TestApp",
            "-c", "Debug"
        ])
        
        XCTAssertEqual(result.exitCode, 0, "Command-specific short flags should work")
        
        GoldenFileManager.assertMatchesGolden(result: result, name: "command-specific-flags-short")
    }
    
    func testBooleanFlags() {
        let result = CLITestHarness.executeCommand([
            "--project", testProjectPath,
            "add-folder",
            "TestFolder",
            "Sources",
            "TestApp",
            "--recursive"
        ])
        
        // This might fail if TestFolder doesn't exist, but we're testing argument parsing
        GoldenFileManager.assertMatchesGolden(result: result, name: "boolean-flags")
    }
    
    // MARK: - Invalid Arguments Tests
    
    func testUnknownGlobalFlag() {
        let result = CLITestHarness.executeCommand([
            "--unknown-flag",
            "list-targets"
        ])

        XCTAssert(result.exitCode == 1 || result.exitCode == 64, "Unknown global flag should fail")
        XCTAssertTrue(
            result.stderr.contains("Unknown flag") || result.stderr.contains("Unknown option"),
            "Should report unknown flag"
        )

        GoldenFileManager.assertMatchesGolden(
            result: result,
            name: "unknown-global-flag",
            category: "errors"
        )
    }
    
    func testUnknownCommandFlag() {
        let result = CLITestHarness.executeCommand([
            "--project", testProjectPath,
            "list-targets",
            "--unknown-flag"
        ])

        XCTAssert(result.exitCode == 1 || result.exitCode == 64, "Unknown command flag should fail")
        XCTAssertTrue(
            result.stderr.contains("Unknown flag") || result.stderr.contains("Unknown option"),
            "Should report unknown flag"
        )

        GoldenFileManager.assertMatchesGolden(
            result: result,
            name: "unknown-command-flag",
            category: "errors"
        )
    }
    
    func testMissingFlagValue() {
        let result = CLITestHarness.executeCommand([
            "--project"
            // Missing project path value
        ])

        XCTAssert(result.exitCode == 1 || result.exitCode == 64, "Missing flag value should fail")
        XCTAssertTrue(
            result.stderr.contains("requires") || result.stderr.contains("expects") || result.stderr.contains("Missing"),
            "Should report missing value"
        )

        GoldenFileManager.assertMatchesGolden(
            result: result,
            name: "missing-flag-value",
            category: "errors"
        )
    }
    
    func testEmptyArguments() {
        let result = CLITestHarness.executeCommand([])

        XCTAssertEqual(result.exitCode, 0, "Empty arguments should show help")
        XCTAssertTrue(
            result.stdout.contains("USAGE") || result.stdout.contains("Usage") || result.stdout.contains("usage"),
            "Should display usage information"
        )

        GoldenFileManager.assertMatchesGolden(result: result, name: "empty-arguments")
    }
    
    // MARK: - Command Help Tests
    
    func testCommandSpecificHelp() {
        let commands = [
            "add-file",
            "list-targets", 
            "create-groups",
            "validate",
            "add-swift-package"
        ]
        
        for command in commands {
            let result = CLITestHarness.executeCommand([command, "--help"])
            
            XCTAssertEqual(
                result.exitCode, 0,
                "Help for '\(command)' should succeed"
            )
            XCTAssertFalse(
                result.stdout.isEmpty,
                "Help for '\(command)' should produce output"
            )
            
            GoldenFileManager.assertMatchesGolden(
                result: result,
                name: "\(command)-help",
                category: "help"
            )
        }
    }
    
    func testCommandSpecificHelpShortForm() {
        let result = CLITestHarness.executeCommand(["add-file", "-h"])
        
        XCTAssertEqual(result.exitCode, 0, "Command help with -h should work")
        XCTAssertFalse(result.stdout.isEmpty, "Should display help")
        
        GoldenFileManager.assertMatchesGolden(
            result: result,
            name: "add-file-help-short",
            category: "help"
        )
    }
    
    // MARK: - Project Discovery Tests
    
    func testNoProjectFlag() {
        // This test assumes there's no .xcodeproj in the test directory
        let result = CLITestHarness.executeCommand(["list-targets"])

        XCTAssertEqual(result.exitCode, 1, "Should fail when no project found")
        XCTAssertTrue(
            result.stderr.contains("No .xcodeproj") ||
            result.stderr.contains("project file") ||
            result.stderr.contains("Missing expected argument '<project>'"),
            "Should report no project found"
        )

        GoldenFileManager.assertMatchesGolden(
            result: result,
            name: "no-project-found",
            category: "errors"
        )
    }
    
    // MARK: - Multiple Flag Values Tests
    
    func testMultipleTargetFlags() {
        let result = CLITestHarness.executeCommand([
            "--project", testProjectPath,
            "list-files",
            "--target", "TestApp"
        ])
        
        XCTAssertEqual(result.exitCode, 0, "Multiple target flags should work")
        
        GoldenFileManager.assertMatchesGolden(result: result, name: "multiple-target-flags")
    }
    
    // MARK: - Flag Validation Tests
    
    func testIncompatibleFlags() {
        // Test flags that might be incompatible (implementation dependent)
        let result = CLITestHarness.executeCommand([
            "--project", testProjectPath,
            "add-folder",
            "TestFolder",
            "Sources", 
            "TestApp",
            "--create-groups",
            "--no-groups"
        ])
        
        // Document current behavior for incompatible flags
        GoldenFileManager.assertMatchesGolden(result: result, name: "incompatible-flags")
    }
    
    // MARK: - Workspace Commands Argument Tests
    
    func testWorkspaceCommandNoProject() {
        let result = CLITestHarness.executeCommand([
            "list-workspace-projects"
        ])

        // Should succeed even without project flag, or fail gracefully with appropriate error
        XCTAssertTrue(
            result.exitCode == 0 || result.exitCode == 1 || result.exitCode == 64,
            "Workspace command should handle no project gracefully (exit code: \(result.exitCode))"
        )

        GoldenFileManager.assertMatchesGolden(result: result, name: "workspace-no-project")
    }
    
    func testWorkspaceCommandWithProjectFlag() {
        let result = CLITestHarness.executeCommand([
            "--project", testProjectPath,
            "list-workspace-projects"
        ])
        
        // Should ignore project flag for workspace commands
        GoldenFileManager.assertMatchesGolden(result: result, name: "workspace-with-project-flag")
    }
    
    // MARK: - Special Characters in Arguments Tests
    
    func testArgumentsWithSpaces() {
        let result = CLITestHarness.executeCommand([
            "--project", testProjectPath,
            "create-groups",
            "Group With Spaces"
        ])
        
        XCTAssertEqual(result.exitCode, 0, "Arguments with spaces should work")
        
        GoldenFileManager.assertMatchesGolden(result: result, name: "arguments-with-spaces")
    }
    
    func testArgumentsWithSpecialCharacters() {
        let result = CLITestHarness.executeCommand([
            "--project", testProjectPath,
            "create-groups",
            "Group-With_Special.Characters"
        ])
        
        XCTAssertEqual(result.exitCode, 0, "Arguments with special characters should work")
        
        GoldenFileManager.assertMatchesGolden(result: result, name: "arguments-special-chars")
    }
}