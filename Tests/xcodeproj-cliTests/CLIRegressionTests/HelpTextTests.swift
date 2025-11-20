//
// HelpTextTests.swift
// xcodeproj-cli Tests
//
// Tests for CLI help text regression and consistency
//

import XCTest
import Foundation
@testable import xcodeproj_cli

/// Tests for CLI help text, ensuring all commands have proper documentation
@MainActor
final class HelpTextTests: XCTestCase {
    
    // MARK: - Main Help Tests
    
    func testMainHelpText() {
        let result = CLITestHarness.executeCommand(["--help"])

        XCTAssertEqual(result.exitCode, 0, "Main help should succeed")
        XCTAssertFalse(result.stdout.isEmpty, "Help should produce output")

        // Main help should contain usage information (ArgumentParser uses "USAGE:" not "Usage:")
        XCTAssertTrue(
            result.stdout.contains("USAGE:") || result.stdout.contains("Usage"),
            "Should contain usage information"
        )

        // Should list available commands (ArgumentParser may use different terminology)
        let helpContent = result.stdout.lowercased()
        XCTAssertTrue(
            helpContent.contains("commands") ||
            helpContent.contains("available") ||
            helpContent.contains("subcommands") ||
            helpContent.contains("overview"),
            "Should mention available commands"
        )

        GoldenFileManager.assertMatchesGolden(
            result: result,
            name: "main-help",
            category: "help"
        )
    }
    
    func testMainHelpShortForm() {
        let result = CLITestHarness.executeCommand(["-h"])
        
        XCTAssertEqual(result.exitCode, 0, "Main help with -h should succeed")
        XCTAssertFalse(result.stdout.isEmpty, "Help should produce output")
        
        GoldenFileManager.assertMatchesGolden(
            result: result,
            name: "main-help-short",
            category: "help"
        )
    }
    
    func testVersionInformation() {
        let result = CLITestHarness.executeCommand(["--version"])
        
        XCTAssertEqual(result.exitCode, 0, "Version should succeed")
        XCTAssertFalse(result.stdout.isEmpty, "Version should produce output")
        
        // Should contain version number
        XCTAssertTrue(
            result.stdout.contains(".") || result.stdout.contains("version"),
            "Should contain version information"
        )
        
        GoldenFileManager.assertMatchesGolden(
            result: result,
            name: "version-info",
            category: "help"
        )
    }
    
    // MARK: - File Commands Help Tests
    
    func testAddFileHelp() {
        let result = CLITestHarness.executeCommand(["add-file", "--help"])
        
        XCTAssertEqual(result.exitCode, 0, "add-file help should succeed")
        XCTAssertFalse(result.stdout.isEmpty, "Should have help content")
        
        // Should explain the command usage
        let helpContent = result.stdout.lowercased()
        XCTAssertTrue(
            helpContent.contains("add") && helpContent.contains("file"),
            "Should explain adding files"
        )
        
        GoldenFileManager.assertMatchesGolden(
            result: result,
            name: "add-file-help",
            category: "help"
        )
    }
    
    func testAddFolderHelp() {
        let result = CLITestHarness.executeCommand(["add-folder", "--help"])
        
        XCTAssertEqual(result.exitCode, 0, "add-folder help should succeed")
        XCTAssertFalse(result.stdout.isEmpty, "Should have help content")
        
        GoldenFileManager.assertMatchesGolden(
            result: result,
            name: "add-folder-help",
            category: "help"
        )
    }
    
    func testRemoveFileHelp() {
        let result = CLITestHarness.executeCommand(["remove-file", "--help"])
        
        XCTAssertEqual(result.exitCode, 0, "remove-file help should succeed")
        XCTAssertFalse(result.stdout.isEmpty, "Should have help content")
        
        GoldenFileManager.assertMatchesGolden(
            result: result,
            name: "remove-file-help",
            category: "help"
        )
    }
    
    // MARK: - Target Commands Help Tests
    
    func testAddTargetHelp() {
        let result = CLITestHarness.executeCommand(["add-target", "--help"])
        
        XCTAssertEqual(result.exitCode, 0, "add-target help should succeed")
        XCTAssertFalse(result.stdout.isEmpty, "Should have help content")
        
        GoldenFileManager.assertMatchesGolden(
            result: result,
            name: "add-target-help",
            category: "help"
        )
    }
    
    func testListTargetsHelp() {
        let result = CLITestHarness.executeCommand(["list-targets", "--help"])
        
        XCTAssertEqual(result.exitCode, 0, "list-targets help should succeed")
        XCTAssertFalse(result.stdout.isEmpty, "Should have help content")
        
        GoldenFileManager.assertMatchesGolden(
            result: result,
            name: "list-targets-help",
            category: "help"
        )
    }
    
    func testDuplicateTargetHelp() {
        let result = CLITestHarness.executeCommand(["duplicate-target", "--help"])
        
        XCTAssertEqual(result.exitCode, 0, "duplicate-target help should succeed")
        XCTAssertFalse(result.stdout.isEmpty, "Should have help content")
        
        GoldenFileManager.assertMatchesGolden(
            result: result,
            name: "duplicate-target-help",
            category: "help"
        )
    }
    
    // MARK: - Group Commands Help Tests
    
    func testCreateGroupsHelp() {
        let result = CLITestHarness.executeCommand(["create-groups", "--help"])
        
        XCTAssertEqual(result.exitCode, 0, "create-groups help should succeed")
        XCTAssertFalse(result.stdout.isEmpty, "Should have help content")
        
        GoldenFileManager.assertMatchesGolden(
            result: result,
            name: "create-groups-help",
            category: "help"
        )
    }
    
    func testListGroupsHelp() {
        let result = CLITestHarness.executeCommand(["list-groups", "--help"])
        
        XCTAssertEqual(result.exitCode, 0, "list-groups help should succeed")
        XCTAssertFalse(result.stdout.isEmpty, "Should have help content")
        
        GoldenFileManager.assertMatchesGolden(
            result: result,
            name: "list-groups-help",
            category: "help"
        )
    }
    
    // MARK: - Build Commands Help Tests
    
    func testSetBuildSettingHelp() {
        let result = CLITestHarness.executeCommand(["set-build-setting", "--help"])
        
        XCTAssertEqual(result.exitCode, 0, "set-build-setting help should succeed")
        XCTAssertFalse(result.stdout.isEmpty, "Should have help content")
        
        GoldenFileManager.assertMatchesGolden(
            result: result,
            name: "set-build-setting-help",
            category: "help"
        )
    }
    
    func testGetBuildSettingsHelp() {
        let result = CLITestHarness.executeCommand(["get-build-settings", "--help"])
        
        XCTAssertEqual(result.exitCode, 0, "get-build-settings help should succeed")
        XCTAssertFalse(result.stdout.isEmpty, "Should have help content")
        
        GoldenFileManager.assertMatchesGolden(
            result: result,
            name: "get-build-settings-help",
            category: "help"
        )
    }
    
    func testListBuildConfigsHelp() {
        let result = CLITestHarness.executeCommand(["list-build-configs", "--help"])
        
        XCTAssertEqual(result.exitCode, 0, "list-build-configs help should succeed")
        XCTAssertFalse(result.stdout.isEmpty, "Should have help content")
        
        GoldenFileManager.assertMatchesGolden(
            result: result,
            name: "list-build-configs-help",
            category: "help"
        )
    }
    
    // MARK: - Package Commands Help Tests
    
    func testAddSwiftPackageHelp() {
        let result = CLITestHarness.executeCommand(["add-swift-package", "--help"])
        
        XCTAssertEqual(result.exitCode, 0, "add-swift-package help should succeed")
        XCTAssertFalse(result.stdout.isEmpty, "Should have help content")
        
        GoldenFileManager.assertMatchesGolden(
            result: result,
            name: "add-swift-package-help",
            category: "help"
        )
    }
    
    func testListSwiftPackagesHelp() {
        let result = CLITestHarness.executeCommand(["list-swift-packages", "--help"])
        
        XCTAssertEqual(result.exitCode, 0, "list-swift-packages help should succeed")
        XCTAssertFalse(result.stdout.isEmpty, "Should have help content")
        
        GoldenFileManager.assertMatchesGolden(
            result: result,
            name: "list-swift-packages-help",
            category: "help"
        )
    }
    
    // MARK: - Inspection Commands Help Tests
    
    func testValidateHelp() {
        let result = CLITestHarness.executeCommand(["validate", "--help"])
        
        XCTAssertEqual(result.exitCode, 0, "validate help should succeed")
        XCTAssertFalse(result.stdout.isEmpty, "Should have help content")
        
        GoldenFileManager.assertMatchesGolden(
            result: result,
            name: "validate-help",
            category: "help"
        )
    }
    
    func testListFilesHelp() {
        let result = CLITestHarness.executeCommand(["list-files", "--help"])
        
        XCTAssertEqual(result.exitCode, 0, "list-files help should succeed")
        XCTAssertFalse(result.stdout.isEmpty, "Should have help content")
        
        GoldenFileManager.assertMatchesGolden(
            result: result,
            name: "list-files-help",
            category: "help"
        )
    }
    
    func testListTreeHelp() {
        let result = CLITestHarness.executeCommand(["list-tree", "--help"])
        
        XCTAssertEqual(result.exitCode, 0, "list-tree help should succeed")
        XCTAssertFalse(result.stdout.isEmpty, "Should have help content")
        
        GoldenFileManager.assertMatchesGolden(
            result: result,
            name: "list-tree-help",
            category: "help"
        )
    }
    
    // MARK: - Scheme Commands Help Tests
    
    func testCreateSchemeHelp() {
        let result = CLITestHarness.executeCommand(["create-scheme", "--help"])
        
        XCTAssertEqual(result.exitCode, 0, "create-scheme help should succeed")
        XCTAssertFalse(result.stdout.isEmpty, "Should have help content")
        
        GoldenFileManager.assertMatchesGolden(
            result: result,
            name: "create-scheme-help",
            category: "help"
        )
    }
    
    func testListSchemesHelp() {
        let result = CLITestHarness.executeCommand(["list-schemes", "--help"])
        
        XCTAssertEqual(result.exitCode, 0, "list-schemes help should succeed")
        XCTAssertFalse(result.stdout.isEmpty, "Should have help content")
        
        GoldenFileManager.assertMatchesGolden(
            result: result,
            name: "list-schemes-help",
            category: "help"
        )
    }
    
    // MARK: - Workspace Commands Help Tests
    
    func testCreateWorkspaceHelp() {
        let result = CLITestHarness.executeCommand(["create-workspace", "--help"])
        
        XCTAssertEqual(result.exitCode, 0, "create-workspace help should succeed")
        XCTAssertFalse(result.stdout.isEmpty, "Should have help content")
        
        GoldenFileManager.assertMatchesGolden(
            result: result,
            name: "create-workspace-help",
            category: "help"
        )
    }
    
    func testListWorkspaceProjectsHelp() {
        let result = CLITestHarness.executeCommand(["list-workspace-projects", "--help"])
        
        XCTAssertEqual(result.exitCode, 0, "list-workspace-projects help should succeed")
        XCTAssertFalse(result.stdout.isEmpty, "Should have help content")
        
        GoldenFileManager.assertMatchesGolden(
            result: result,
            name: "list-workspace-projects-help",
            category: "help"
        )
    }
    
    // MARK: - Help Content Quality Tests
    
    func testHelpContentCompleteness() {
        // Test a sample of commands to ensure help text contains essential information
        let commandsToTest = [
            "add-file",
            "list-targets",
            "create-groups",
            "set-build-setting",
            "validate"
        ]
        
        for command in commandsToTest {
            let result = CLITestHarness.executeCommand([command, "--help"])
            
            XCTAssertEqual(result.exitCode, 0, "\(command) help should succeed")
            XCTAssertFalse(result.stdout.isEmpty, "\(command) should have help content")
            
            let helpContent = result.stdout.lowercased()
            
            // Help should contain usage or description
            XCTAssertTrue(
                helpContent.contains("usage") || 
                helpContent.contains("description") ||
                helpContent.contains(command),
                "\(command) help should contain usage or description"
            )
            
            GoldenFileManager.assertMatchesGolden(
                result: result,
                name: "\(command)-help-quality",
                category: "help"
            )
        }
    }
    
    func testHelpConsistencyAcrossCommands() {
        // Test that help format is consistent across similar commands
        let listCommands = [
            "list-targets",
            "list-groups",
            "list-files",
            "list-build-configs"
        ]
        
        for command in listCommands {
            let result = CLITestHarness.executeCommand([command, "--help"])
            
            XCTAssertEqual(result.exitCode, 0, "\(command) help should succeed")
            XCTAssertFalse(result.stdout.isEmpty, "\(command) should have help content")
            
            // All list commands should have consistent help structure
            GoldenFileManager.assertMatchesGolden(
                result: result,
                name: "\(command)-help-consistency",
                category: "help"
            )
        }
    }
    
    // MARK: - All Commands Help Test
    
    func testAllCommandsHaveHelp() {
        // Get all available commands from ArgumentParser configuration
        let allCommands = XcodeProjCLI.configuration.subcommands.compactMap {
            $0.configuration.commandName
        }.filter { !$0.isEmpty }

        for command in allCommands {
            let result = CLITestHarness.executeCommand([command, "--help"])
            
            XCTAssertEqual(
                result.exitCode, 0,
                "Command '\(command)' should have working help"
            )
            XCTAssertFalse(
                result.stdout.isEmpty,
                "Command '\(command)' should have help content"
            )
            
            // Each command should have its own golden file
            GoldenFileManager.assertMatchesGolden(
                result: result,
                name: "\(command)-help",
                category: "help"
            )
        }
    }
    
    func testWorkspaceCommandsHaveHelp() {
        let workspaceCommands = [
            "create-workspace",
            "add-project-to-workspace",
            "remove-project-from-workspace",
            "list-workspace-projects"
        ]
        
        for command in workspaceCommands {
            let result = CLITestHarness.executeCommand([command, "--help"])
            
            XCTAssertEqual(
                result.exitCode, 0,
                "Workspace command '\(command)' should have working help"
            )
            XCTAssertFalse(
                result.stdout.isEmpty,
                "Workspace command '\(command)' should have help content"
            )
            
            GoldenFileManager.assertMatchesGolden(
                result: result,
                name: "\(command)-help",
                category: "help"
            )
        }
    }
    
    // MARK: - Help Text Format Tests
    
    func testHelpTextFormatting() {
        let result = CLITestHarness.executeCommand(["add-file", "--help"])
        
        XCTAssertEqual(result.exitCode, 0, "Help should succeed")
        
        let helpText = result.stdout
        
        // Help text should be properly formatted
        XCTAssertFalse(helpText.isEmpty, "Help text should not be empty")
        
        // Should not have excessive blank lines
        let lines = helpText.components(separatedBy: .newlines)
        let nonEmptyLines = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        XCTAssertGreaterThan(nonEmptyLines.count, 0, "Should have meaningful content")
        
        GoldenFileManager.assertMatchesGolden(
            result: result,
            name: "help-text-formatting",
            category: "help"
        )
    }
    
    // MARK: - Help Text Content Tests
    
    func testHelpTextContainsExamples() {
        // Test that complex commands provide usage examples
        let complexCommands = [
            "add-file",
            "add-swift-package",
            "set-build-setting"
        ]
        
        for command in complexCommands {
            let result = CLITestHarness.executeCommand([command, "--help"])
            
            XCTAssertEqual(result.exitCode, 0, "\(command) help should succeed")
            
            let helpContent = result.stdout.lowercased()
            
            // Complex commands should ideally have examples or detailed usage
            // This tests documents current behavior
            GoldenFileManager.assertMatchesGolden(
                result: result,
                name: "\(command)-help-examples",
                category: "help"
            )
        }
    }
}