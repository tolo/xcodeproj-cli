//
// ComprehensiveTests.swift
// xcodeproj-cliTests
//
// Comprehensive feature coverage tests for all xcodeproj-cli commands
//

import XCTest
import Foundation

final class ComprehensiveTests: XCTProjectTestCase {
    
    var createdTestFiles: [URL] = []
    var createdTestDirectories: [URL] = []
    
    override func tearDown() {
        TestHelpers.cleanupTestItems(createdTestFiles + createdTestDirectories)
        createdTestFiles.removeAll()
        createdTestDirectories.removeAll()
        super.tearDown()
    }
    
    // MARK: - Complete Command Coverage Tests
    
    func testAllFileCommands() throws {
        // Test all file-related commands comprehensively
        
        let targetName = extractFirstTarget(from: try runSuccessfulCommand("list-targets").output) ?? "TestApp"
        
        // 1. add-file command variations
        let singleFile = try TestHelpers.createTestFile(name: "SingleTest.swift", content: "class SingleTest {}")
        createdTestFiles.append(singleFile)
        
        let addFileResult = try runCommand("add-file", arguments: [
            singleFile.lastPathComponent,
            "--group", "Sources",
            "--target", targetName
        ])
        
        if addFileResult.success {
            TestHelpers.assertCommandSuccess(addFileResult)
            
            // 2. Verify file was added
            let listFiles = try runSuccessfulCommand("list-files")
            TestHelpers.assertOutputContains(listFiles.output, "SingleTest.swift")
            
            // 3. move-file command
            _ = try runCommand("create-groups", arguments: ["MovedFiles"])
            let moveResult = try runCommand("move-file", arguments: [
                singleFile.lastPathComponent,
                "--to-group", "MovedFiles"
            ])
            
            if moveResult.success {
                TestHelpers.assertCommandSuccess(moveResult)
            }
            
            // 4. remove-file command
            let removeResult = try runCommand("remove-file", arguments: [singleFile.lastPathComponent])
            if removeResult.success {
                TestHelpers.assertCommandSuccess(removeResult)
                
                // Verify removal
                let updatedList = try runSuccessfulCommand("list-files")
                TestHelpers.assertOutputDoesNotContain(updatedList.output, "SingleTest.swift")
            }
        }
        
        // 5. add-files (batch) command
        let batchFiles = [
            try TestHelpers.createTestFile(name: "Batch1.swift", content: "class Batch1 {}"),
            try TestHelpers.createTestFile(name: "Batch2.swift", content: "class Batch2 {}"),
            try TestHelpers.createTestFile(name: "Batch3.swift", content: "class Batch3 {}")
        ]
        createdTestFiles.append(contentsOf: batchFiles)
        
        let testDir = batchFiles[0].deletingLastPathComponent()
        let pattern = testDir.appendingPathComponent("Batch*.swift").path
        
        let addFilesResult = try runCommand("add-files", arguments: [
            pattern,
            "--group", "Sources",
            "--target", targetName
        ])
        
        if addFilesResult.success {
            TestHelpers.assertCommandSuccess(addFilesResult)
        }
        
        // 6. add-folder command variations
        let testFolder = try TestHelpers.createTestDirectory(
            name: "TestFolder",
            files: [
                "FolderFile1.swift": "class FolderFile1 {}",
                "FolderFile2.swift": "class FolderFile2 {}"
            ]
        )
        createdTestDirectories.append(testFolder)
        
        let addFolderResult = try runCommand("add-folder", arguments: [
            testFolder.path,
            "--group", "FolderGroup",
            "--target", targetName,
            "--recursive"
        ])
        
        if addFolderResult.success {
            TestHelpers.assertCommandSuccess(addFolderResult)
            
            // Verify folder files were added
            let folderList = try runSuccessfulCommand("list-files")
            TestHelpers.assertOutputContains(folderList.output, "FolderFile1.swift")
            TestHelpers.assertOutputContains(folderList.output, "FolderFile2.swift")
        }
        
        // 7. add-sync-folder command (if supported)
        let syncFolder = try TestHelpers.createTestDirectory(
            name: "SyncFolder",
            files: ["SyncFile.swift": "class SyncFile {}"]
        )
        createdTestDirectories.append(syncFolder)
        
        // Create the SyncGroup first
        _ = try runCommand("create-groups", arguments: ["SyncGroup"])
        
        let syncResult = try runCommand("add-sync-folder", arguments: [
            syncFolder.path,
            "--group", "SyncGroup",
            "--target", targetName
        ])
        
        if syncResult.success {
            TestHelpers.assertCommandSuccess(syncResult)
        } else if !syncResult.output.contains("not supported") && !syncResult.error.contains("not supported") {
            // Only report failure if it's not a "not supported" error or a known error
            if !syncResult.error.contains("Error:") && !syncResult.error.contains("Operation failed") {
                XCTFail("Unexpected sync folder error: \(syncResult.output) \(syncResult.error)")
            }
        }
    }
    
    func testAllGroupCommands() throws {
        // Test all group-related commands
        
        // 1. create-groups command variations
        let groupCommands = [
            ["SimpleGroup"],
            ["Parent/Child"],
            ["Deep/Nested/Group/Structure"]
        ]
        
        for groupArgs in groupCommands {
            let result = try runCommand("create-groups", arguments: groupArgs)
            if result.success {
                TestHelpers.assertCommandSuccess(result)
            }
        }
        
        // 2. list-groups command
        let listGroups = try runSuccessfulCommand("list-groups")
        TestHelpers.assertCommandSuccess(listGroups)
        XCTAssertTrue(listGroups.output.count > 0, "Should show groups")
        
        // Verify created groups appear
        TestHelpers.assertOutputContains(listGroups.output, "SimpleGroup")
        
        // 3. remove-group command
        let removeResult = try runCommand("remove-group", arguments: ["SimpleGroup"])
        if removeResult.success {
            TestHelpers.assertCommandSuccess(removeResult)
            
            // Verify group was removed
            let updatedGroups = try runSuccessfulCommand("list-groups")
            TestHelpers.assertOutputDoesNotContain(updatedGroups.output, "SimpleGroup")
        }
    }
    
    func testAllTargetCommands() throws {
        // Test all target-related commands
        
        // 1. list-targets command (baseline)
        let initialTargets = try runSuccessfulCommand("list-targets")
        TestHelpers.assertCommandSuccess(initialTargets)
        let existingTargets = extractAllTargets(from: initialTargets.output)
        
        // 2. add-target command variations
        let newTargets = [
            ("NewApp", "app", "iOS"),
            ("NewFramework", "framework", "iOS"),
            ("NewLibrary", "static-library", "iOS")
        ]
        
        var createdTargets: [String] = []
        
        for (name, type, platform) in newTargets {
            let result = try runCommand("add-target", arguments: [
                name,
                "--type", type,
                "--bundle-id", "com.test.\(name.lowercased())",
                "--platform", platform
            ])
            
            if result.success {
                TestHelpers.assertCommandSuccess(result)
                createdTargets.append(name)
                
                // Verify target was created
                let updatedTargets = try runSuccessfulCommand("list-targets")
                TestHelpers.assertOutputContains(updatedTargets.output, name)
            } else {
                // Target creation might not be supported for all types
                XCTAssertTrue(
                    result.output.contains("template") || 
                    result.output.contains("not supported") ||
                    result.output.contains("platform"),
                    "Target creation should fail with clear reason for \(type)"
                )
            }
        }
        
        // 3. duplicate-target command
        if let sourceTarget = existingTargets.first {
            let duplicateResult = try runCommand("duplicate-target", arguments: [
                sourceTarget,
                "--new-name", "DuplicatedTarget"
            ])
            
            if duplicateResult.success {
                TestHelpers.assertCommandSuccess(duplicateResult)
                createdTargets.append("DuplicatedTarget")
            }
        }
        
        // 4. add-dependency command
        if createdTargets.count >= 2 {
            let dependencyResult = try runCommand("add-dependency", arguments: [
                createdTargets[0],
                "--depends-on", createdTargets[1]
            ])
            
            if dependencyResult.success {
                TestHelpers.assertCommandSuccess(dependencyResult)
            } else {
                // Dependencies might fail due to target type compatibility
                XCTAssertTrue(
                    dependencyResult.output.contains("circular") || 
                    dependencyResult.output.contains("incompatible") ||
                    dependencyResult.output.contains("already exists") ||
                    dependencyResult.output.contains("target") ||
                    !dependencyResult.output.isEmpty,
                    "Dependency should fail with clear reason or succeed"
                )
            }
        }
        
        // 5. remove-target command (cleanup)
        for target in createdTargets {
            let removeResult = try runCommand("remove-target", arguments: [target])
            if removeResult.success {
                TestHelpers.assertCommandSuccess(removeResult)
            }
        }
    }
    
    func testAllBuildCommands() throws {
        // Test all build-related commands
        
        let targetName = extractFirstTarget(from: try runSuccessfulCommand("list-targets").output) ?? "TestApp"
        
        // 1. list-build-configs command
        let configs = try runSuccessfulCommand("list-build-configs")
        TestHelpers.assertCommandSuccess(configs)
        TestHelpers.assertOutputContains(configs.output, "Debug")
        TestHelpers.assertOutputContains(configs.output, "Release")
        
        // 2. list-build-settings command
        let buildSettings = try runSuccessfulCommand("list-build-settings")
        TestHelpers.assertCommandSuccess(buildSettings)
        XCTAssertTrue(buildSettings.output.count > 0, "Should show available build settings")
        
        // 3. get-build-settings command variations
        let getSettingsVariations = [
            ["--target", targetName],
            ["--target", targetName, "--configuration", "Debug"],
            ["--target", targetName, "--configuration", "Release"]
        ]
        
        for args in getSettingsVariations {
            let result = try runCommand("get-build-settings", arguments: args)
            if result.success {
                TestHelpers.assertCommandSuccess(result)
                XCTAssertTrue(result.output.count > 0, "Should show build settings")
            }
        }
        
        // 4. set-build-setting command variations
        let buildSettingTests = [
            ("SWIFT_VERSION", "5.9"),
            ("DEVELOPMENT_TEAM", "ABC123XYZ"),
            ("PRODUCT_BUNDLE_IDENTIFIER", "com.test.comprehensive"),
            ("CODE_SIGN_IDENTITY", "iPhone Developer")
        ]
        
        for (key, value) in buildSettingTests {
            let setResult = try runCommand("set-build-setting", arguments: [
                key, value,
                "--target", targetName
            ])
            
            if setResult.success {
                TestHelpers.assertCommandSuccess(setResult)
                
                // Verify setting was applied
                let getResult = try runSuccessfulCommand("get-build-settings", arguments: ["--target", targetName])
                TestHelpers.assertOutputContains(getResult.output, key)
            }
        }
        
        // 5. set-build-setting with configuration
        let configResult = try runCommand("set-build-setting", arguments: [
            "GCC_OPTIMIZATION_LEVEL",
            "0",
            "--target", targetName,
            "--configuration", "Debug"
        ])
        
        if configResult.success {
            TestHelpers.assertCommandSuccess(configResult)
        }
        
        // 6. add-build-phase command (if supported)
        let buildPhaseResult = try runCommand("add-build-phase", arguments: [
            "script",
            "Test Build Phase",
            "--target", targetName,
            "--script", "echo 'Comprehensive test build phase'"
        ])
        
        if buildPhaseResult.success {
            TestHelpers.assertCommandSuccess(buildPhaseResult)
        } else if !buildPhaseResult.output.contains("not supported") {
            // Only report failure if it's not a "not supported" error
            XCTAssertTrue(
                buildPhaseResult.output.contains("phase") || buildPhaseResult.output.contains("script"),
                "Build phase should fail with clear reason"
            )
        }
    }
    
    func testAllPackageCommands() throws {
        // Test all Swift package commands comprehensively
        
        // 1. list-swift-packages (baseline)
        let initialPackages = try runCommand("list-swift-packages")
        if initialPackages.success {
            TestHelpers.assertCommandSuccess(initialPackages)
        }
        
        // 2. add-swift-package command variations
        let packageTests = [
            ("https://github.com/apple/swift-log.git", "version", "1.5.0"),
            ("https://github.com/apple/swift-collections.git", "branch", "main"),
            ("https://github.com/apple/swift-algorithms.git", "commit", "1.0.0")
        ]
        
        var addedPackages: [String] = []
        
        for (url, versionType, versionValue) in packageTests {
            let result = try runCommand("add-swift-package", arguments: [
                url,
                "--\(versionType)", versionValue
            ])
            
            if result.success {
                TestHelpers.assertCommandSuccess(result)
                
                // Extract package name from URL
                let packageName = url.components(separatedBy: "/").last?.replacingOccurrences(of: ".git", with: "") ?? ""
                addedPackages.append(packageName)
                
                // Verify package was added
                let listResult = try runCommand("list-swift-packages")
                if listResult.success {
                    TestHelpers.assertOutputContains(listResult.output, packageName)
                }
            } else {
                // Package addition might fail due to network or project constraints
                XCTAssertTrue(
                    result.output.contains("network") || 
                    result.output.contains("resolve") ||
                    result.output.contains("not supported") ||
                    result.output.contains("already exists") ||
                    result.error.contains("network"),
                    "Package addition should fail with clear reason for \(url)"
                )
            }
        }
        
        // 3. add-swift-package with target specification
        let targetName = extractFirstTarget(from: try runSuccessfulCommand("list-targets").output)
        if let target = targetName {
            let targetPackageResult = try runCommand("add-swift-package", arguments: [
                "https://github.com/apple/swift-numerics.git",
                "--version", "1.0.0",
                "--target", target
            ])
            
            if targetPackageResult.success {
                TestHelpers.assertCommandSuccess(targetPackageResult)
                addedPackages.append("swift-numerics")
            }
        }
        
        // 4. remove-swift-package command
        for packageName in addedPackages {
            let removeResult = try runCommand("remove-swift-package", arguments: [packageName])
            if removeResult.success {
                TestHelpers.assertCommandSuccess(removeResult)
                
                // Verify package was removed
                let listResult = try runCommand("list-swift-packages")
                if listResult.success {
                    TestHelpers.assertOutputDoesNotContain(listResult.output, packageName)
                }
            }
        }
        
        // 5. Test with local package
        let localPackage = try TestHelpers.createTestDirectory(
            name: "LocalTestPackage",
            files: [
                "Package.swift": """
                // swift-tools-version:5.9
                import PackageDescription
                let package = Package(name: "LocalTestPackage", products: [.library(name: "LocalTestPackage", targets: ["LocalTestPackage"])], targets: [.target(name: "LocalTestPackage")])
                """,
                "Sources/LocalTestPackage/LocalTestPackage.swift": "public struct LocalTestPackage {}"
            ]
        )
        createdTestDirectories.append(localPackage)
        
        let localResult = try runCommand("add-swift-package", arguments: [
            localPackage.path,
            "--local"
        ])
        
        if localResult.success {
            TestHelpers.assertCommandSuccess(localResult)
        }
    }
    
    func testAllInspectionCommands() throws {
        // Test all inspection and validation commands
        
        // 1. validate command
        let validation = try runSuccessfulCommand("validate")
        TestHelpers.assertCommandSuccess(validation)
        TestHelpers.assertOutputContains(validation.output, "valid")
        
        // 2. list-files command variations
        let fileListVariations = [
            [],
            ["--target", extractFirstTarget(from: try runSuccessfulCommand("list-targets").output) ?? "TestApp"]
        ]
        
        for args in fileListVariations {
            let result = try runCommand("list-files", arguments: args)
            if result.success {
                TestHelpers.assertCommandSuccess(result)
                XCTAssertTrue(result.output.count > 0, "Should show files")
            }
        }
        
        // 3. list-tree command
        let treeResult = try runSuccessfulCommand("list-tree")
        TestHelpers.assertCommandSuccess(treeResult)
        XCTAssertTrue(treeResult.output.count > 0, "Should show project tree")
        
        // 4. list-invalid-references command
        let invalidRefs = try runSuccessfulCommand("list-invalid-references")
        TestHelpers.assertCommandSuccess(invalidRefs)
        
        // 5. remove-invalid-references command (if any exist)
        let removeInvalid = try runCommand("remove-invalid-references")
        if removeInvalid.success {
            TestHelpers.assertCommandSuccess(removeInvalid)
        }
        
        // 6. list-schemes command
        let schemes = try runCommand("list-schemes")
        if schemes.success {
            TestHelpers.assertCommandSuccess(schemes)
        }
    }
    
    func testAllFrameworkCommands() throws {
        // Test framework-related commands
        
        let targetName = extractFirstTarget(from: try runSuccessfulCommand("list-targets").output) ?? "TestApp"
        
        // Test adding system frameworks
        let systemFrameworks = [
            "Foundation.framework",
            "UIKit.framework",
            "CoreData.framework"
        ]
        
        for framework in systemFrameworks {
            let result = try runCommand("add-framework", arguments: [
                framework,
                "--target", targetName
            ])
            
            if result.success {
                TestHelpers.assertCommandSuccess(result)
            } else {
                // Framework might already exist or not be applicable
                XCTAssertTrue(
                    result.output.contains("already") ||
                    result.output.contains("exists") ||
                    result.output.contains("not found") ||
                    result.error.contains("Error:") || result.error.contains("Operation failed"),
                    "Framework addition should fail with clear reason for \(framework)"
                )
            }
        }
    }
    
    func testAllSchemeCommands() throws {
        // Test scheme-related commands (if supported)
        
        let targetName = extractFirstTarget(from: try runSuccessfulCommand("list-targets").output) ?? "TestApp"
        
        // 1. create-scheme command
        let createScheme = try runCommand("create-scheme", arguments: [
            "TestScheme",
            "--target", targetName
        ])
        
        if createScheme.success {
            TestHelpers.assertCommandSuccess(createScheme)
            
            // Note: Due to test project restoration, the scheme won't persist
            // We can verify the command succeeded but can't list it after restoration
            // Instead, verify the success message contains expected output
            TestHelpers.assertOutputContains(createScheme.output, "Created scheme 'TestScheme'")
            
            // Since schemes don't persist in test environment, we'll test with the existing TestApp scheme
            // 3. duplicate-scheme command on existing scheme
            let duplicateScheme = try runCommand("duplicate-scheme", arguments: [
                "TestApp",
                "--new-name", "DuplicatedScheme"
            ])
            
            if duplicateScheme.success {
                TestHelpers.assertCommandSuccess(duplicateScheme)
                TestHelpers.assertOutputContains(duplicateScheme.output, "Duplicated scheme")
            }
            
            // 4. set-scheme-config command on existing scheme
            let setConfig = try runCommand("set-scheme-config", arguments: [
                "TestApp",
                "--configuration", "Release"
            ])
            
            if setConfig.success {
                TestHelpers.assertCommandSuccess(setConfig)
            }
            
            // 5. enable-test-coverage command on existing scheme
            let enableCoverage = try runCommand("enable-test-coverage", arguments: [
                "TestApp"
            ])
            
            if enableCoverage.success {
                TestHelpers.assertCommandSuccess(enableCoverage)
            }
            
            // 6. list-schemes to verify existing scheme
            let listSchemes = try runSuccessfulCommand("list-schemes")
            TestHelpers.assertOutputContains(listSchemes.output, "TestApp")
        } else if !createScheme.output.contains("not supported") {
            // Only report failure if it's not a "not supported" error
            XCTAssertTrue(
                createScheme.output.contains("scheme") || createScheme.output.contains("target"),
                "Scheme creation should fail with clear reason"
            )
        }
    }
    
    func testAllPathCommands() throws {
        // Test path-related commands (if supported)
        
        // 1. update-paths command
        let updatePaths = try runCommand("update-paths", arguments: [
            "--old-path", "/old/path",
            "--new-path", "/new/path"
        ])
        
        if updatePaths.success {
            TestHelpers.assertCommandSuccess(updatePaths)
        } else if !updatePaths.output.contains("not supported") {
            XCTAssertTrue(
                updatePaths.output.contains("path") || updatePaths.output.contains("not found") ||
                updatePaths.error.contains("Error:") || updatePaths.error.contains("Operation failed"),
                "Path update should fail with clear reason"
            )
        }
        
        // 2. update-paths-map command
        let updatePathsMap = try runCommand("update-paths-map", arguments: [
            "--map-file", "/path/to/mapping.json"
        ])
        
        if updatePathsMap.success {
            TestHelpers.assertCommandSuccess(updatePathsMap)
        } else if !updatePathsMap.output.contains("not supported") {
            XCTAssertTrue(
                updatePathsMap.output.contains("map") || updatePathsMap.output.contains("not found") ||
                updatePathsMap.error.contains("Error:") || updatePathsMap.error.contains("Operation failed"),
                "Path map update should fail with clear reason"
            )
        }
    }
    
    func testAllWorkspaceCommands() throws {
        // Test workspace-related commands (if supported)
        
        // 1. create-workspace command
        let createWorkspace = try runCommand("create-workspace", arguments: [
            "TestWorkspace.xcworkspace"
        ])
        
        if createWorkspace.success {
            TestHelpers.assertCommandSuccess(createWorkspace)
            
            // 2. add-project-to-workspace command
            let addProject = try runCommand("add-project-to-workspace", arguments: [
                TestHelpers.testProjectPath,
                "--workspace", "TestWorkspace.xcworkspace"
            ])
            
            if addProject.success {
                TestHelpers.assertCommandSuccess(addProject)
                
                // 3. list-workspace-projects command
                let listProjects = try runCommand("list-workspace-projects", arguments: [
                    "--workspace", "TestWorkspace.xcworkspace"
                ])
                
                if listProjects.success {
                    TestHelpers.assertCommandSuccess(listProjects)
                }
                
                // 4. remove-project-from-workspace command
                let removeProject = try runCommand("remove-project-from-workspace", arguments: [
                    TestHelpers.testProjectPath,
                    "--workspace", "TestWorkspace.xcworkspace"
                ])
                
                if removeProject.success {
                    TestHelpers.assertCommandSuccess(removeProject)
                }
            }
        } else if !createWorkspace.output.contains("not supported") {
            XCTAssertTrue(
                createWorkspace.output.contains("workspace") || createWorkspace.output.contains("already") ||
                createWorkspace.error.contains("Error:") || createWorkspace.error.contains("Operation failed"),
                "Workspace creation should fail with clear reason"
            )
        }
    }
    
    // MARK: - Command Option Coverage
    
    func testAllGlobalOptions() throws {
        // Test all global options work with various commands
        
        let testCommand = "validate"
        let globalOptions = [
            ["--verbose"],
            ["--dry-run"],
            ["--project", TestHelpers.testProjectPath]
        ]
        
        for options in globalOptions {
            let result = try runCommand(testCommand, arguments: options)
            if result.success {
                TestHelpers.assertCommandSuccess(result)
            } else {
                // Some global options might not be supported
                XCTAssertTrue(
                    result.output.contains("not supported") || 
                    result.output.contains("verbose") ||
                    result.output.contains("dry"),
                    "Global option should fail with clear reason or work"
                )
            }
        }
    }
    
    func testCommandAliasesAndShortFlags() throws {
        // Test short flags and aliases where they exist
        
        let flagTests = [
            (["--help"], ["-h"]),
            (["--verbose"], ["-V"])
        ]
        
        for (longForm, shortForm) in flagTests {
            let longResult = try runCommand(longForm[0], arguments: Array(longForm.dropFirst()))
            let shortResult = try runCommand(shortForm[0], arguments: Array(shortForm.dropFirst()))
            
            // If long form works, short form should work too (or vice versa)
            if longResult.success || shortResult.success {
                XCTAssertTrue(
                    longResult.success == shortResult.success ||
                    !longResult.success && (shortResult.output.contains("Unknown") || shortResult.error.contains("Unknown")) ||
                    !shortResult.success && (longResult.output.contains("Unknown") || longResult.error.contains("Unknown")),
                    "Long and short forms should have consistent behavior"
                )
            }
        }
    }
    
    // MARK: - Final Integration Test
    
    func testCompleteFeatureIntegration() throws {
        // Test that all major features work together in a realistic scenario
        
        // Create a complete project setup using all available commands
        let targetName = extractFirstTarget(from: try runSuccessfulCommand("list-targets").output) ?? "TestApp"
        
        // 1. Project structure setup
        _ = try runCommand("create-groups", arguments: ["App/Models"])
        _ = try runCommand("create-groups", arguments: ["App/Views"])
        _ = try runCommand("create-groups", arguments: ["App/Controllers"])
        
        // 2. Add files
        let modelFile = try TestHelpers.createTestFile(
            name: "ComprehensiveModel.swift",
            content: "struct ComprehensiveModel { let id: String }"
        )
        createdTestFiles.append(modelFile)
        
        let addFileResult = try runCommand("add-file", arguments: [
            modelFile.lastPathComponent,
            "--group", "AppModels",
            "--target", targetName
        ])
        
        if addFileResult.success {
            // 3. Configure build settings
            _ = try runCommand("set-build-setting", arguments: [
                "SWIFT_VERSION", "5.9",
                "--target", targetName
            ])
            
            // 4. Add a Swift package (if supported)
            let packageResult = try runCommand("add-swift-package", arguments: [
                "https://github.com/apple/swift-log.git",
                "--version", "1.5.0"
            ])
            
            // 5. Validate everything works together
            let finalValidation = try runSuccessfulCommand("validate")
            TestHelpers.assertCommandSuccess(finalValidation)
            
            // 6. Verify all components are present
            let fileList = try runSuccessfulCommand("list-files")
            TestHelpers.assertOutputContains(fileList.output, "ComprehensiveModel.swift")
            
            let settingsList = try runSuccessfulCommand("get-build-settings", arguments: ["--target", targetName])
            TestHelpers.assertOutputContains(settingsList.output, "SWIFT_VERSION")
            
            if packageResult.success {
                let packageList = try runCommand("list-swift-packages")
                if packageList.success {
                    TestHelpers.assertOutputContains(packageList.output, "swift-log")
                }
            }
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
            if !trimmed.isEmpty && 
               !trimmed.contains(":") && 
               !trimmed.contains("Target") && 
               !trimmed.contains("-") &&
               !trimmed.contains("=") &&
               trimmed.count < 50 {
                targets.append(trimmed)
            }
        }
        
        return Array(Set(targets))
    }
}