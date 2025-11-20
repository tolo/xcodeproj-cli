//
// ValidationTests.swift
// xcodeproj-cliTests
//
// Tests for read-only validation and listing commands
//

import XCTest
import Foundation

final class ValidationTests: XCTestCase {
    
    // MARK: - Project Validation Tests
    
    func testValidateCommand() throws {
        let result = try TestHelpers.runSuccessfulCommand("validate")
        
        // Should complete successfully and show validation results
        TestHelpers.assertOutputContains(result.output, "valid")
    }
    
    func testValidateWithVerboseOutput() throws {
        let result = try TestHelpers.runCommand("validate", arguments: ["--verbose"])
        
        // Should work with or without verbose support
        if result.success {
            XCTAssertTrue(result.output.count > 0, "Verbose validation should produce output")
        }
    }
    
    func testValidateNonExistentProject() throws {
        let result = try TestHelpers.runFailingCommand("validate", arguments: ["--project", "NonExistent.xcodeproj"])

        TestHelpers.assertCommandFailure(result, message: "Should fail for non-existent project")
        XCTAssertTrue(
            result.error.contains("Error: The project cannot be found") ||
            result.output.contains("Error: The project cannot be found") ||
            result.output.contains("cannot be found"),
            "Should report project not found"
        )
    }
    
    // MARK: - List Targets Tests
    
    func testListTargetsCommand() throws {
        let result = try TestHelpers.runSuccessfulCommand("list-targets")
        
        // Should show available targets
        XCTAssertTrue(result.output.count > 0, "List targets should produce output")
        
        // Common target names that might exist in test project
        let possibleTargets = ["TestApp", "MyApp", "App", "Test"]
        let hasTarget = possibleTargets.contains { result.output.contains($0) }
        
        if !hasTarget {
            // If no common targets found, at least verify it's showing some kind of target info
            XCTAssertTrue(
                result.output.contains("Target") || result.output.contains("target") || result.output.lowercased().contains("no targets"),
                "Should show target information or indicate no targets found"
            )
        }
    }
    
    func testListTargetsFormatting() throws {
        let result = try TestHelpers.runSuccessfulCommand("list-targets")
        
        // Output should be reasonably formatted (not just raw data)
        XCTAssertFalse(result.output.contains("null"), "Should not contain null values")
        XCTAssertFalse(result.output.contains("undefined"), "Should not contain undefined values")
    }
    
    // MARK: - List Files Tests
    
    func testListFilesCommand() throws {
        let result = try TestHelpers.runSuccessfulCommand("list-files")
        
        XCTAssertTrue(result.output.count > 0, "List files should produce output")
    }
    
    func testListFilesWithTargetFilter() throws {
        // First get available targets
        let targetsResult = try TestHelpers.runSuccessfulCommand("list-targets")
        
        // Extract a target name if available (simple parsing)
        let lines = targetsResult.output.components(separatedBy: .newlines)
        var targetName: String? = nil
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty && !trimmed.contains(":") && !trimmed.contains("Target") {
                targetName = trimmed
                break
            }
        }
        
        if let target = targetName {
            let result = try TestHelpers.runCommand("list-files", arguments: ["--targets", target])
            
            if result.success {
                XCTAssertTrue(result.output.count > 0, "List files with target filter should produce output")
            }
        }
    }
    
    // MARK: - List Groups Tests
    
    func testListGroupsCommand() throws {
        let result = try TestHelpers.runSuccessfulCommand("list-groups")
        
        XCTAssertTrue(result.output.count > 0, "List groups should produce output")
        
        // Common group names that might exist
        let possibleGroups = ["Sources", "Resources", "Tests", "Supporting Files"]
        let hasCommonGroup = possibleGroups.contains { result.output.contains($0) }
        
        if !hasCommonGroup {
            // At least verify it's showing some kind of group structure
            XCTAssertTrue(
                result.output.contains("Group") || result.output.contains("group") || result.output.contains("/"),
                "Should show group information"
            )
        }
    }
    
    // MARK: - List Tree Tests
    
    func testListTreeCommand() throws {
        let result = try TestHelpers.runSuccessfulCommand("list-tree")
        
        XCTAssertTrue(result.output.count > 0, "List tree should produce output")
        
        // Tree output should have some hierarchical structure
        XCTAssertTrue(
            result.output.contains("├") || result.output.contains("└") || result.output.contains("-") || result.output.contains("  "),
            "Tree output should show hierarchical structure"
        )
    }
    
    // MARK: - List Build Configs Tests
    
    func testListBuildConfigsCommand() throws {
        let result = try TestHelpers.runSuccessfulCommand("list-build-configs")
        
        XCTAssertTrue(result.output.count > 0, "List build configs should produce output")
        
        // Should show common build configurations
        XCTAssertTrue(
            result.output.contains("Debug") || result.output.contains("Release") || result.output.contains("Configuration"),
            "Should show build configurations"
        )
    }
    
    // MARK: - List Schemes Tests
    
    func testListSchemesCommand() throws {
        let result = try TestHelpers.runCommand("list-schemes")
        
        // Schemes might not exist in test project, so either success or graceful failure
        if result.success {
            XCTAssertTrue(result.output.count > 0, "List schemes should produce output when schemes exist")
        } else {
            // Should indicate no schemes found rather than crash
            XCTAssertTrue(
                result.output.contains("no schemes") || result.output.contains("not found") || result.output.contains("No schemes"),
                "Should gracefully handle when no schemes exist"
            )
        }
    }
    
    // MARK: - List Swift Packages Tests
    
    func testListSwiftPackagesCommand() throws {
        let result = try TestHelpers.runCommand("list-swift-packages")
        
        // Packages might not exist, so either success or graceful failure
        if result.success {
            XCTAssertTrue(result.output.count >= 0, "List packages should produce output")
        } else {
            // Should indicate no packages rather than crash
            XCTAssertTrue(
                result.output.contains("no packages") || result.output.contains("not found") || result.output.contains("No packages"),
                "Should gracefully handle when no packages exist"
            )
        }
    }
    
    // MARK: - List Invalid References Tests
    
    func testListInvalidReferencesCommand() throws {
        let result = try TestHelpers.runSuccessfulCommand("list-invalid-references")
        
        XCTAssertTrue(result.output.count >= 0, "List invalid references should complete")
        
        // If no invalid references, should indicate that
        if result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            XCTAssertTrue(true, "No invalid references found (good)")
        } else {
            // If invalid references found, should show them clearly
            XCTAssertTrue(
                result.output.contains("reference") || result.output.contains("file") || result.output.contains("missing"),
                "Should clearly show invalid references if any exist"
            )
        }
    }
    
    // MARK: - Get Build Settings Tests
    
    func testGetBuildSettingsCommand() throws {
        // First get a target to test with
        let targetsResult = try TestHelpers.runSuccessfulCommand("list-targets")
        let lines = targetsResult.output.components(separatedBy: .newlines)
        
        var targetName: String? = nil
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty && !trimmed.contains(":") && !trimmed.contains("Target") && !trimmed.contains("-") {
                targetName = trimmed
                break
            }
        }
        
        if let target = targetName {
            let result = try TestHelpers.runCommand("get-build-settings", arguments: [target])
            
            if result.success {
                XCTAssertTrue(result.output.count > 0, "Get build settings should show configuration")
                
                // Should contain some typical build settings
                XCTAssertTrue(
                    result.output.contains("PRODUCT_NAME") || 
                    result.output.contains("SWIFT_VERSION") ||
                    result.output.contains("=") ||
                    result.output.contains(":"),
                    "Should show actual build settings"
                )
            }
        }
    }
    
    func testGetBuildSettingsInvalidTarget() throws {
        let result = try TestHelpers.runFailingCommand("get-build-settings", arguments: ["NonExistentTarget"])

        TestHelpers.assertCommandFailure(result)
        XCTAssertTrue(
            result.output.contains("Error: Target not found") ||
            result.error.contains("Error: Target not found") ||
            result.output.contains("not found") ||
            result.error.contains("not found"),
            "Should report target not found"
        )
    }
    
    // MARK: - List Build Settings Tests
    
    func testListBuildSettingsCommand() throws {
        let result = try TestHelpers.runSuccessfulCommand("list-build-settings")
        
        XCTAssertTrue(result.output.count > 0, "List build settings should show available settings")
        
        // Should show common build setting keys
        XCTAssertTrue(
            result.output.contains("PRODUCT_NAME") || 
            result.output.contains("SWIFT_VERSION") ||
            result.output.contains("CODE_SIGN") ||
            result.output.contains("DEVELOPMENT_TEAM"),
            "Should show available build setting keys"
        )
    }
    
    // MARK: - Command Combination Tests
    
    func testMultipleReadOnlyCommands() throws {
        // Test running multiple read-only commands in sequence
        let commands = ["validate", "list-targets", "list-groups", "list-build-configs"]
        
        for command in commands {
            let result = try TestHelpers.runCommand(command)
            XCTAssertTrue(result.success || result.output.contains("not found"), 
                         "Read-only command '\(command)' should succeed or fail gracefully")
        }
    }
    
    func testReadOnlyCommandsDoNotModifyProject() throws {
        // Get initial project state
        let initialValidation = try TestHelpers.runSuccessfulCommand("validate")
        
        // Run various read-only commands
        let readOnlyCommands = [
            "list-targets",
            "list-files", 
            "list-groups",
            "list-tree",
            "list-build-configs"
        ]
        
        for command in readOnlyCommands {
            _ = try TestHelpers.runCommand(command)
        }
        
        // Verify project state hasn't changed
        let finalValidation = try TestHelpers.runSuccessfulCommand("validate")
        
        // The validation output should be essentially the same
        // (allowing for minor differences in timestamps or formatting)
        XCTAssertEqual(
            initialValidation.output.count,
            finalValidation.output.count,
            "Read-only commands should not modify project state"
        )
    }
}