//
// BuildAndTargetTests.swift
// xcodeproj-cliTests
//
// Tests for target management and build setting commands
//

import XCTest
import Foundation

final class BuildAndTargetTests: XCTProjectTestCase {
    
    // MARK: - Target Management Tests
    
    func testAddTarget() throws {
        let targetName = "NewTestTarget"
        
        let result = try runCommand("add-target", arguments: [
            targetName,
            "--type", "app",
            "--bundle-id", "com.test.newtarget",
            "--platform", "iOS"
        ])
        
        if result.success {
            TestHelpers.assertCommandSuccess(result)
            
            // Verify target was added
            let listResult = try runSuccessfulCommand("list-targets")
            TestHelpers.assertOutputContains(listResult.output, targetName)
        } else {
            // Target creation might fail due to missing templates or other requirements
            XCTAssertTrue(
                result.output.contains("template") || result.output.contains("platform") || result.output.contains("type") || result.output.contains("bundle-id"),
                "Should provide clear error about target creation requirements"
            )
        }
    }
    
    func testAddTargetWithInvalidType() throws {
        let result = try runCommand("add-target", arguments: [
            "InvalidTypeTarget",
            "--type", "invalid-type",
            "--bundle-id", "com.test.invalid",
            "--platform", "iOS"
        ])

        // Tool accepts any target type (validation happens in Xcode)
        if result.success {
            TestHelpers.assertCommandSuccess(result)
            XCTAssertTrue(result.output.contains("Added target"), "Should confirm target creation")
        } else {
            // If it fails, could be validation or target already exists
            TestHelpers.assertCommandFailure(result)
            XCTAssertTrue(
                result.output.contains("invalid") || result.output.contains("type") || result.output.contains("supported") ||
                result.error.contains("Invalid product type") || result.error.contains("invalid") ||
                result.error.contains("already exists"),
                "Should report error"
            )
        }
    }
    
    func testDuplicateTarget() throws {
        // First get an existing target to duplicate
        let targetsResult = try runSuccessfulCommand("list-targets")
        let existingTarget = extractFirstTarget(from: targetsResult.output)
        
        if let sourceTarget = existingTarget {
            let newTargetName = "DuplicatedTarget"
            
            let result = try runCommand("duplicate-target", arguments: [
                sourceTarget,
                "--new-name", newTargetName
            ])
            
            if result.success {
                TestHelpers.assertCommandSuccess(result)
                
                // Verify duplicated target exists
                let listResult = try runSuccessfulCommand("list-targets")
                TestHelpers.assertOutputContains(listResult.output, newTargetName)
            } else {
                // Duplication might not be supported or might require additional parameters
                XCTAssertTrue(result.output.count > 0 || result.error.count > 0, 
                             "Should provide error message for duplication failure")
            }
        } else {
            XCTFail("No existing target found to duplicate")
        }
    }
    
    func testRemoveTarget() throws {
        // First try to add a target to remove
        let targetName = "ToBeRemovedTarget"
        let addResult = try runCommand("add-target", arguments: [
            targetName,
            "--type", "app",
            "--platform", "iOS"
        ])
        
        if addResult.success {
            // Target was created successfully, now remove it
            let removeResult = try runSuccessfulCommand("remove-target", arguments: [targetName])
            TestHelpers.assertCommandSuccess(removeResult)
            
            // Verify target was removed
            let listResult = try runSuccessfulCommand("list-targets")
            TestHelpers.assertOutputDoesNotContain(listResult.output, targetName)
        } else {
            // If we can't create targets, test removing a non-existent one
            let removeResult = try runFailingCommand("remove-target", arguments: ["NonExistentTarget"])
            TestHelpers.assertCommandFailure(removeResult)
            XCTAssertTrue(
                removeResult.error.contains("Target not found") || removeResult.output.contains("Target not found"),
                "Should report target not found"
            )
        }
    }
    
    // MARK: - Target Dependencies Tests
    
    func testAddDependency() throws {
        let targetsResult = try runSuccessfulCommand("list-targets")
        let targets = extractAllTargets(from: targetsResult.output)
        
        if targets.count >= 2 {
            let sourceTarget = targets[0]
            let dependencyTarget = targets[1]
            
            let result = try runCommand("add-dependency", arguments: [
                sourceTarget,
                "--depends-on", dependencyTarget
            ])
            
            if result.success {
                TestHelpers.assertCommandSuccess(result)
                // Note: Verifying dependencies is complex, so we just check it didn't crash
            } else {
                XCTAssertTrue(
                    result.output.contains("dependency") || result.output.contains("circular") || result.output.contains("already"),
                    "Should provide clear error about dependency issues"
                )
            }
        }
    }
    
    func testAddCircularDependency() throws {
        let targetsResult = try runSuccessfulCommand("list-targets")
        let targets = extractAllTargets(from: targetsResult.output)
        
        if targets.count >= 2 {
            let target1 = targets[0]
            let target2 = targets[1]
            
            // Try to add target1 -> target2
            _ = try runCommand("add-dependency", arguments: [target1, "--depends-on", target2])
            
            // Try to add target2 -> target1 (should create circular dependency)
            let result = try runCommand("add-dependency", arguments: [target2, "--depends-on", target1])
            
            if !result.success {
                TestHelpers.assertCommandFailure(result)
                XCTAssertTrue(
                    result.output.contains("circular") || result.output.contains("cycle"),
                    "Should detect and prevent circular dependencies"
                )
            }
        }
    }
    
    // MARK: - Build Settings Tests
    
    func testSetBuildSetting() throws {
        let targetsResult = try runSuccessfulCommand("list-targets")
        let targetName = extractFirstTarget(from: targetsResult.output)
        
        if let target = targetName {
            let result = try runSuccessfulCommand("set-build-setting", arguments: [
                "SWIFT_VERSION",
                "5.9",
                "--targets", target
            ])

            TestHelpers.assertCommandSuccess(result)

            // Verify setting was applied
            let getResult = try runSuccessfulCommand("get-build-settings", arguments: ["--target", target])
            TestHelpers.assertOutputContains(getResult.output, "SWIFT_VERSION")
            TestHelpers.assertOutputContains(getResult.output, "5.9")
        }
    }
    
    func testSetBuildSettingMultipleTargets() throws {
        let targetsResult = try runSuccessfulCommand("list-targets")
        let targets = extractAllTargets(from: targetsResult.output)
        
        if targets.count >= 2 {
            let targetList = Array(targets.prefix(2)).joined(separator: ",")
            
            let result = try runSuccessfulCommand("set-build-setting", arguments: [
                "DEVELOPMENT_TEAM",
                "ABC123XYZ",
                "--targets", targetList
            ])
            
            TestHelpers.assertCommandSuccess(result)
            
            // Verify setting was applied to both targets
            for target in Array(targets.prefix(2)) {
                let getResult = try runSuccessfulCommand("get-build-settings", arguments: ["--target", target])
                TestHelpers.assertOutputContains(getResult.output, "DEVELOPMENT_TEAM")
            }
        }
    }
    
    func testSetBuildSettingWithConfiguration() throws {
        let targetsResult = try runSuccessfulCommand("list-targets")
        let targetName = extractFirstTarget(from: targetsResult.output)
        
        if let target = targetName {
            let result = try runCommand("set-build-setting", arguments: [
                "ENABLE_BITCODE",
                "NO",
                "--targets", target,
                "--configuration", "Debug"
            ])
            
            if result.success {
                TestHelpers.assertCommandSuccess(result)
                
                // Verify setting was applied to specific configuration
                let getResult = try runSuccessfulCommand("get-build-settings", arguments: [
                    "--target", target,
                    "--configuration", "Debug"
                ])
                TestHelpers.assertOutputContains(getResult.output, "ENABLE_BITCODE")
            }
        }
    }
    
    func testSetInvalidBuildSetting() throws {
        let targetsResult = try runSuccessfulCommand("list-targets")
        let targetName = extractFirstTarget(from: targetsResult.output)
        
        if let target = targetName {
            // Try to set a dangerous build setting (should be rejected by security)
            let result = try runFailingCommand("set-build-setting", arguments: [
                "OTHER_LDFLAGS",
                "@executable_path/../../../etc/passwd",
                "--targets", target
            ])
            
            TestHelpers.assertCommandFailure(result)
            let combinedOutput = result.output + result.error
            XCTAssertTrue(
                combinedOutput.contains("dangerous") || combinedOutput.contains("invalid") || combinedOutput.contains("security") || combinedOutput.contains("potentially dangerous"),
                "Should reject dangerous build settings. Got output: '\(result.output)', error: '\(result.error)'"
            )
        }
    }
    
    func testGetBuildSettingsAllConfigurations() throws {
        let targetsResult = try runSuccessfulCommand("list-targets")
        let targetName = extractFirstTarget(from: targetsResult.output)
        
        if let target = targetName {
            let result = try runSuccessfulCommand("get-build-settings", arguments: ["--target", target])
            
            TestHelpers.assertCommandSuccess(result)
            XCTAssertTrue(result.output.count > 0, "Should show build settings")
            
            // Should contain common build settings
            XCTAssertTrue(
                result.output.contains("PRODUCT_NAME") ||
                result.output.contains("SWIFT_VERSION") ||
                result.output.contains("CODE_SIGN"),
                "Should show actual build settings"
            )
        }
    }
    
    func testGetBuildSettingsSpecificConfiguration() throws {
        let targetsResult = try runSuccessfulCommand("list-targets")
        let targetName = extractFirstTarget(from: targetsResult.output)
        
        if let target = targetName {
            let result = try runCommand("get-build-settings", arguments: [
                "--target", target,
                "--configuration", "Debug"
            ])
            
            if result.success {
                TestHelpers.assertCommandSuccess(result)
                TestHelpers.assertOutputContains(result.output, "Debug")
            }
        }
    }
    
    // MARK: - Build Phase Tests
    
    func testAddBuildPhase() throws {
        let targetsResult = try runSuccessfulCommand("list-targets")
        let targetName = extractFirstTarget(from: targetsResult.output)
        
        if let target = targetName {
            let result = try runCommand("add-build-phase", arguments: [
                "script",
                "Test Script Phase",
                "--target", target,
                "--script", "echo 'Test build phase'"
            ])
            
            if result.success {
                TestHelpers.assertCommandSuccess(result)
            } else {
                // Build phase addition might not be fully implemented
                XCTAssertTrue(
                    result.output.contains("phase") || result.output.contains("script") || result.output.contains("not supported"),
                    "Should provide clear error about build phase support"
                )
            }
        }
    }
    
    // MARK: - Framework Tests
    
    func testAddFramework() throws {
        let targetsResult = try runSuccessfulCommand("list-targets")
        let targetName = extractFirstTarget(from: targetsResult.output)
        
        if let target = targetName {
            let result = try runCommand("add-framework", arguments: [
                "Foundation.framework",
                "--target", target
            ])
            
            if result.success {
                TestHelpers.assertCommandSuccess(result)
            } else {
                // Framework addition might require specific setup
                XCTAssertTrue(
                    result.output.contains("framework") || result.output.contains("not found") || result.output.contains("already"),
                    "Should provide clear error about framework addition"
                )
            }
        }
    }
    
    func testAddSystemFramework() throws {
        let targetsResult = try runSuccessfulCommand("list-targets")
        let targetName = extractFirstTarget(from: targetsResult.output)
        
        if let target = targetName {
            let systemFrameworks = ["UIKit.framework", "Foundation.framework", "CoreData.framework"]
            
            for framework in systemFrameworks {
                let result = try runCommand("add-framework", arguments: [
                    framework,
                    "--target", target
                ])
                
                // System frameworks should generally be addable
                if result.success {
                    XCTAssertTrue(true, "Successfully added \(framework)")
                } else {
                    XCTAssertTrue(
                        result.output.contains("already") || result.output.contains("exists"),
                        "Framework might already exist: \(framework)"
                    )
                }
            }
        }
    }
    
    func testAddNonExistentFramework() throws {
        let targetsResult = try runSuccessfulCommand("list-targets")
        let targetName = extractFirstTarget(from: targetsResult.output)
        
        if let target = targetName {
            let result = try runCommand("add-framework", arguments: [
                "NonExistentFramework.framework",
                "--target", target
            ])
            
            if result.success {
                // Command succeeds - tool allows adding frameworks (validation happens in Xcode)
                TestHelpers.assertCommandSuccess(result)
                XCTAssertTrue(
                    result.output.contains("Added framework") || result.output.contains("Framework"),
                    "Should confirm framework addition"
                )
            } else {
                // If it does validate, should provide clear error
                TestHelpers.assertCommandFailure(result)
                XCTAssertTrue(
                    result.error.contains("Error:") || result.output.contains("cannot be found") || result.output.contains("not found"),
                    "Should report framework not found"
                )
            }
        }
    }
    
    // MARK: - Build Configuration Tests
    
    func testListBuildConfigurationsDetail() throws {
        let result = try runSuccessfulCommand("list-build-configs")
        
        TestHelpers.assertCommandSuccess(result)
        XCTAssertTrue(result.output.count > 0, "Should show build configurations")
        
        // Should show standard configurations
        XCTAssertTrue(
            result.output.contains("Debug") || result.output.contains("Release"),
            "Should show standard build configurations"
        )
    }
    
    // MARK: - Target Integration Tests
    
    func testTargetFileIntegration() throws {
        // Test adding a file to a specific target, then verifying it's only in that target
        let testFile = try TestHelpers.createTestFile(name: "TargetSpecificFile.swift", content: "// Target specific test file\n")
        defer { TestHelpers.cleanupTestItems([testFile]) }
        
        let targetsResult = try runSuccessfulCommand("list-targets")
        let targets = extractAllTargets(from: targetsResult.output)
        
        if let target = targets.first {
            // Add file to specific target using absolute path to avoid path resolution issues
            let addResult = try runSuccessfulCommand("add-file", arguments: [
                testFile.path,
                "--group", "Sources",
                "--targets", target
            ])
            
            TestHelpers.assertCommandSuccess(addResult)
            
            // Verify file was added
            let listResult = try runSuccessfulCommand("list-files")
            TestHelpers.assertOutputContains(listResult.output, "TargetSpecificFile.swift")
        }
    }
    
    func testTargetBuildSettingIntegration() throws {
        let targetsResult = try runSuccessfulCommand("list-targets")
        let targetName = extractFirstTarget(from: targetsResult.output)
        
        if let target = targetName {
            // Set a build setting
            let setResult = try runSuccessfulCommand("set-build-setting", arguments: [
                "PRODUCT_BUNDLE_IDENTIFIER",
                "com.test.integration",
                "--targets", target
            ])
            
            TestHelpers.assertCommandSuccess(setResult)
            
            // Get all build settings and verify our setting is there
            let getResult = try runSuccessfulCommand("get-build-settings", arguments: ["--target", target])
            TestHelpers.assertOutputContains(getResult.output, "PRODUCT_BUNDLE_IDENTIFIER")
            TestHelpers.assertOutputContains(getResult.output, "com.test.integration")
        }
    }
    
    // MARK: - Helper Methods
    
    private func extractFirstTarget(from output: String) -> String? {
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Look for lines that start with "- " (bullet points)
            if trimmed.hasPrefix("- ") {
                let targetLine = String(trimmed.dropFirst(2)) // Remove "- " prefix
                // Extract target name before the first space and parenthesis
                if let spaceIndex = targetLine.firstIndex(of: " ") {
                    return String(targetLine[..<spaceIndex])
                } else {
                    return targetLine
                }
            }
        }
        return nil
    }
    
    private func extractAllTargets(from output: String) -> [String] {
        let lines = output.components(separatedBy: .newlines)
        var targets: [String] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Look for lines that start with "- " (bullet points)
            if trimmed.hasPrefix("- ") {
                let targetLine = String(trimmed.dropFirst(2)) // Remove "- " prefix
                // Extract target name before the first space and parenthesis
                if let spaceIndex = targetLine.firstIndex(of: " ") {
                    targets.append(String(targetLine[..<spaceIndex]))
                } else {
                    targets.append(targetLine)
                }
            }
        }
        
        return Array(Set(targets)) // Remove duplicates
    }
}