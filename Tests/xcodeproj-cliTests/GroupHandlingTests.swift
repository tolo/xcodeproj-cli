//
// GroupHandlingTests.swift
// xcodeproj-cliTests
//
// Tests for group handling improvements (Phase 1 & 2 fixes)
// Related to: ai_docs/group-handling-issues-fix-plan.md
//

import Foundation
import XCTest

final class GroupHandlingTests: XCTProjectTestCase {

  var createdTestFiles: [URL] = []
  var createdTestGroups: [String] = []

  override func tearDown() {
    // Clean up any test files created during tests
    TestHelpers.cleanupTestItems(createdTestFiles)
    createdTestFiles.removeAll()
    createdTestGroups.removeAll()

    super.tearDown()
  }

  // MARK: - Phase 1 Tests: Name Collision Detection

  /// Test that creating a group with the same name as an existing file fails with clear error
  func testCreateGroupWithSameNameAsFile() throws {
    // Create a test file with a simple name (no extension in the name property)
    let testFile = try TestHelpers.createTestFile(
      name: "ThemeService.swift",
      content: "// Test file\nclass ThemeService {}\n"
    )
    createdTestFiles.append(testFile)

    // Add the file to the project first
    let targetName =
      extractFirstTarget(from: try TestHelpers.runSuccessfulCommand("list-targets").output)
      ?? "TestApp"

    try TestHelpers.runSuccessfulCommand(
      "add-file",
      arguments: [
        testFile.path,
        "--group", "Sources",
        "--targets", targetName,
      ])

    // Now try to create a group with the same name as the file (without extension)
    // within the Sources group where the file was added
    // This should fail to prevent project corruption
    let result = try TestHelpers.runCommand(
      "create-groups",
      arguments: ["Sources/ThemeService"])

    // Should fail with clear error message
    XCTAssertFalse(result.success, "Creating group with same name as file should fail")
    XCTAssertTrue(
      result.output.contains("Cannot create group") || result.error.contains("Cannot create group"),
      "Error should mention group creation conflict. Output: \(result.output), Error: \(result.error)"
    )
    XCTAssertTrue(
      result.output.contains("already exists") || result.error.contains("already exists"),
      "Error should mention that name already exists. Output: \(result.output), Error: \(result.error)"
    )
  }

  /// Test that creating a nested group path where intermediate component matches file name fails
  func testCreateNestedGroupsWithFileNameConflict() throws {
    // Create a test file
    let testFile = try TestHelpers.createTestFile(
      name: "ConfigService.swift",
      content: "// Test file\nclass ConfigService {}\n"
    )
    createdTestFiles.append(testFile)

    // Add the file to the project
    let targetName =
      extractFirstTarget(from: try TestHelpers.runSuccessfulCommand("list-targets").output)
      ?? "TestApp"

    try TestHelpers.runSuccessfulCommand(
      "add-file",
      arguments: [
        testFile.path,
        "--group", "Sources",
        "--targets", targetName,
      ])

    // Try to create a nested group path where "ConfigService" is an intermediate component
    // within Sources where the file exists
    // This should fail because ConfigService is already a file
    let result = try TestHelpers.runCommand(
      "create-groups",
      arguments: ["Sources/ConfigService/Utils"])

    // Should fail with clear error message
    XCTAssertFalse(
      result.success, "Creating nested groups with file name conflict should fail")
    XCTAssertTrue(
      result.output.contains("Cannot create group") || result.error.contains("Cannot create group"),
      "Error should mention group creation conflict"
    )
  }

  /// Test that creating groups with file stem (name without extension) is detected
  func testCreateGroupWithSameNameAsFileStem() throws {
    // Create a test file
    let testFile = try TestHelpers.createTestFile(
      name: "NetworkManager.swift",
      content: "// Test file\nclass NetworkManager {}\n"
    )
    createdTestFiles.append(testFile)

    // Add the file to the project
    let targetName =
      extractFirstTarget(from: try TestHelpers.runSuccessfulCommand("list-targets").output)
      ?? "TestApp"

    try TestHelpers.runSuccessfulCommand(
      "add-file",
      arguments: [
        testFile.path,
        "--group", "Sources",
        "--targets", targetName,
      ])

    // Try to create a group with the same stem name within Sources
    let result = try TestHelpers.runCommand(
      "create-groups",
      arguments: ["Sources/NetworkManager"])

    // Should fail because NetworkManager.swift exists
    XCTAssertFalse(
      result.success,
      "Creating group with same stem as file should fail. Output: \(result.output)")
  }

  /// Test that existing groups can still be created without issues
  func testCreateGroupsWorksForNonConflictingNames() throws {
    // Create a test file with a specific name
    let testFile = try TestHelpers.createTestFile(
      name: "DataModel.swift",
      content: "// Test file\nclass DataModel {}\n"
    )
    createdTestFiles.append(testFile)

    // Add the file to the project
    let targetName =
      extractFirstTarget(from: try TestHelpers.runSuccessfulCommand("list-targets").output)
      ?? "TestApp"

    try TestHelpers.runSuccessfulCommand(
      "add-file",
      arguments: [
        testFile.path,
        "--group", "Sources",
        "--targets", targetName,
      ])

    // Create a group with a different name - should succeed
    let result = try TestHelpers.runSuccessfulCommand(
      "create-groups",
      arguments: ["ViewModels"])

    createdTestGroups.append("ViewModels")

    TestHelpers.assertCommandSuccess(result)
    TestHelpers.assertOutputContains(result.output, "Created group")
  }

  /// Test that creating groups works correctly when no file conflicts exist
  func testCreateNestedGroupsWithoutConflicts() throws {
    // Create nested groups without any file conflicts
    let result = try TestHelpers.runSuccessfulCommand(
      "create-groups",
      arguments: ["App/Core/Services"])

    createdTestGroups.append("App")

    TestHelpers.assertCommandSuccess(result)
    TestHelpers.assertOutputContains(result.output, "Created group")
  }

  // MARK: - Phase 2 Tests: Improved Error Messages

  /// Test that group not found error message is helpful and suggests using simple names
  func testGroupNotFoundErrorMessage() throws {
    let testFile = try TestHelpers.createTestFile(
      name: "TestFile.swift",
      content: "// Test\n"
    )
    createdTestFiles.append(testFile)

    let targetName =
      extractFirstTarget(from: try TestHelpers.runSuccessfulCommand("list-targets").output)
      ?? "TestApp"

    // Try to add file to non-existent group
    let result = try TestHelpers.runCommand(
      "add-file",
      arguments: [
        testFile.path,
        "--group", "NonExistentGroup",
        "--targets", targetName,
      ])

    // Should fail with helpful error message
    XCTAssertFalse(result.success, "Adding file to non-existent group should fail")

    let errorOutput = result.output + result.error

    // Check for helpful guidance in error message
    XCTAssertTrue(
      errorOutput.contains("Group not found"),
      "Error should mention group not found"
    )
    XCTAssertTrue(
      errorOutput.contains("simple group name") || errorOutput.contains("list-groups"),
      "Error should provide guidance about using simple names or list-groups command"
    )
  }

  /// Test that error message suggests using last component when path with slashes is used
  func testGroupNotFoundWithPathSuggestsSimpleName() throws {
    let testFile = try TestHelpers.createTestFile(
      name: "TestFile2.swift",
      content: "// Test\n"
    )
    createdTestFiles.append(testFile)

    let targetName =
      extractFirstTarget(from: try TestHelpers.runSuccessfulCommand("list-targets").output)
      ?? "TestApp"

    // Try to add file using a path-like group name
    let result = try TestHelpers.runCommand(
      "add-file",
      arguments: [
        testFile.path,
        "--group", "App/Source/Models",
        "--targets", targetName,
      ])

    // Should fail with helpful error message
    XCTAssertFalse(result.success, "Adding file with path-like group name should fail")

    let errorOutput = result.output + result.error

    // Check that error mentions the issue with using paths
    XCTAssertTrue(
      errorOutput.contains("Group not found"),
      "Error should mention group not found"
    )

    // Should suggest using simple name or provide guidance
    XCTAssertTrue(
      errorOutput.contains("simple") || errorOutput.contains("list-groups")
        || errorOutput.contains("last component"),
      "Error should provide guidance about paths vs simple names"
    )
  }

  // MARK: - Phase 1 Additional Tests: Error Propagation

  /// Test that addFolder with createGroups propagates errors (Task 1.1)
  func testAddFolderWithGroupCollisionPropagatesError() throws {
    // Test that errors from ensureGroupHierarchy propagate properly
    // Create a file that will cause collision, then try to create groups through it

    let testFile = try TestHelpers.createTestFile(
      name: "Services.swift",
      content: "// Test service file\nclass Services {}\n"
    )
    createdTestFiles.append(testFile)

    let targetName =
      extractFirstTarget(from: try TestHelpers.runSuccessfulCommand("list-targets").output)
      ?? "TestApp"

    // Add file to Sources
    try TestHelpers.runSuccessfulCommand(
      "add-file",
      arguments: [
        testFile.path,
        "--group", "Sources",
        "--targets", targetName,
      ])

    // Now try to create a group hierarchy that goes through Services
    // This should fail because Services.swift is a file, not a group
    let result = try TestHelpers.runCommand(
      "create-groups",
      arguments: ["Sources/Services/Utils"])

    // Should fail with clear error about collision
    XCTAssertFalse(result.success, "Creating group through file should fail")
    XCTAssertTrue(
      result.output.contains("Cannot create group") || result.error.contains("Cannot create group"),
      "Error should propagate and mention collision. Output: \(result.output), Error: \(result.error)"
    )
  }

  // MARK: - Phase 1 Additional Tests: Cache Consistency

  /// Test that cache remains valid on group creation failure (Task 1.2)
  func testCacheRemainsValidOnGroupCreationFailure() throws {
    // First, create "Core" group successfully
    try TestHelpers.runSuccessfulCommand(
      "create-groups",
      arguments: ["Core"])

    // Create a file that will cause collision in Core
    let testFile = try TestHelpers.createTestFile(
      name: "DataLayer.swift",
      content: "// Data layer\n"
    )
    createdTestFiles.append(testFile)

    let targetName =
      extractFirstTarget(from: try TestHelpers.runSuccessfulCommand("list-targets").output)
      ?? "TestApp"

    // Add file to Core
    try TestHelpers.runSuccessfulCommand(
      "add-file",
      arguments: [
        testFile.path,
        "--group", "Core",
        "--targets", targetName,
      ])

    // Attempt nested group creation that will fail partway through
    // "Core/DataLayer/Models" should fail when it hits DataLayer
    let result = try TestHelpers.runCommand(
      "create-groups",
      arguments: ["Core/DataLayer/Models"])

    // Should fail at DataLayer
    XCTAssertFalse(result.success, "Creating groups with file collision should fail")

    // Now verify that "Core" is still usable (cache wasn't corrupted)
    // by attempting to add another file to it
    let testFile2 = try TestHelpers.createTestFile(
      name: "CoreFile.swift",
      content: "// Core file\n"
    )
    createdTestFiles.append(testFile2)

    let addResult = try TestHelpers.runCommand(
      "add-file",
      arguments: [
        testFile2.path,
        "--group", "Core",
        "--targets", targetName,
      ])

    // This should succeed because Core's cache entry is still valid
    XCTAssertTrue(
      addResult.success,
      "Should be able to use Core group after failed subgroup creation. Output: \(addResult.output), Error: \(addResult.error)"
    )
  }

  // MARK: - Phase 1 Additional Tests: File Stem Matching

  /// Test collision detection with files having multiple dots (Task 1.3)
  func testFileCollisionDetectionWithMultipleDots() throws {
    // Test "file.test.swift"
    let testFile = try TestHelpers.createTestFile(
      name: "Component.test.swift",
      content: "// Test file\n"
    )
    createdTestFiles.append(testFile)

    let targetName =
      extractFirstTarget(from: try TestHelpers.runSuccessfulCommand("list-targets").output)
      ?? "TestApp"

    try TestHelpers.runSuccessfulCommand(
      "add-file",
      arguments: [
        testFile.path,
        "--group", "Sources",
        "--targets", targetName,
      ])

    // Try to create group "Component.test" - should fail because that's the file stem
    let result1 = try TestHelpers.runCommand(
      "create-groups",
      arguments: ["Sources/Component.test"])

    XCTAssertFalse(result1.success, "Should detect collision with file stem 'Component.test'")

    // Try to create group "Component" - should succeed as it's only part of the name
    let result2 = try TestHelpers.runSuccessfulCommand(
      "create-groups",
      arguments: ["Sources/Component"])

    TestHelpers.assertCommandSuccess(result2)
  }

  /// Test collision detection with files without extension (Task 1.3)
  func testFileCollisionDetectionWithNoExtension() throws {
    let testFile = try TestHelpers.createTestFile(
      name: "Makefile",
      content: "# Makefile\n"
    )
    createdTestFiles.append(testFile)

    let targetName =
      extractFirstTarget(from: try TestHelpers.runSuccessfulCommand("list-targets").output)
      ?? "TestApp"

    try TestHelpers.runSuccessfulCommand(
      "add-file",
      arguments: [
        testFile.path,
        "--group", "Sources",
        "--targets", targetName,
      ])

    // Try to create group "Makefile" - should fail
    let result = try TestHelpers.runCommand(
      "create-groups",
      arguments: ["Sources/Makefile"])

    XCTAssertFalse(
      result.success, "Should detect collision with file without extension 'Makefile'")
  }

  /// Test collision detection with hidden files (Task 1.3)
  func testFileCollisionDetectionWithHiddenFiles() throws {
    let testFile = try TestHelpers.createTestFile(
      name: ".gitignore",
      content: "*.swp\n"
    )
    createdTestFiles.append(testFile)

    let targetName =
      extractFirstTarget(from: try TestHelpers.runSuccessfulCommand("list-targets").output)
      ?? "TestApp"

    try TestHelpers.runSuccessfulCommand(
      "add-file",
      arguments: [
        testFile.path,
        "--group", "Sources",
        "--targets", targetName,
      ])

    // Try to create group ".gitignore" - should fail
    let result = try TestHelpers.runCommand(
      "create-groups",
      arguments: ["Sources/.gitignore"])

    XCTAssertFalse(result.success, "Should detect collision with hidden file '.gitignore'")
  }

  /// Test that ConfigService.swift blocks "Config" group creation (Task 1.3)
  func testFileCollisionWithSimilarNames() throws {
    let testFile = try TestHelpers.createTestFile(
      name: "ConfigService.swift",
      content: "// Config service\n"
    )
    createdTestFiles.append(testFile)

    let targetName =
      extractFirstTarget(from: try TestHelpers.runSuccessfulCommand("list-targets").output)
      ?? "TestApp"

    try TestHelpers.runSuccessfulCommand(
      "add-file",
      arguments: [
        testFile.path,
        "--group", "Sources",
        "--targets", targetName,
      ])

    // Try to create group "Config" - should fail because "ConfigService.swift" has stem "ConfigService"
    // This should NOT fail because "Config" != "ConfigService"
    let result1 = try TestHelpers.runSuccessfulCommand(
      "create-groups",
      arguments: ["Sources/Config"])

    TestHelpers.assertCommandSuccess(result1)

    // Try to create group "ConfigService" - should fail because file stem matches
    let result2 = try TestHelpers.runCommand(
      "create-groups",
      arguments: ["Sources/ConfigService"])

    XCTAssertFalse(
      result2.success,
      "Should detect collision with file stem 'ConfigService'. Output: \(result2.output)")
  }

  // MARK: - Phase 2 Tests: Path Resolution

  /// Test adding file with simple group name (backward compatibility)
  func testAddFileWithSimpleName() throws {
    let testFile = try TestHelpers.createTestFile(
      name: "SimpleFile.swift",
      content: "// Simple test\n"
    )
    createdTestFiles.append(testFile)

    let targetName =
      extractFirstTarget(from: try TestHelpers.runSuccessfulCommand("list-targets").output)
      ?? "TestApp"

    // Should work with simple group name
    let result = try TestHelpers.runSuccessfulCommand(
      "add-file",
      arguments: [
        testFile.path,
        "--group", "Sources",
        "--targets", targetName,
      ])

    TestHelpers.assertCommandSuccess(result)
    TestHelpers.assertOutputContains(result.output, "Added")
  }

  /// Test adding file with hierarchical path
  func testAddFileWithHierarchicalPath() throws {
    // Create nested group structure
    try TestHelpers.runSuccessfulCommand(
      "create-groups",
      arguments: ["App/Source/Models"])

    let testFile = try TestHelpers.createTestFile(
      name: "PathFile.swift",
      content: "// Path test\n"
    )
    createdTestFiles.append(testFile)

    let targetName =
      extractFirstTarget(from: try TestHelpers.runSuccessfulCommand("list-targets").output)
      ?? "TestApp"

    // Should work with hierarchical path
    let result = try TestHelpers.runSuccessfulCommand(
      "add-file",
      arguments: [
        testFile.path,
        "--group", "App/Source/Models",
        "--targets", targetName,
      ])

    TestHelpers.assertCommandSuccess(result)
    TestHelpers.assertOutputContains(result.output, "Added")
  }

  /// Test that invalid hierarchical path fails (no silent fallback)
  func testAddFileWithInvalidPathFailsExplicitly() throws {
    // Create a "Models" group at root
    try TestHelpers.runSuccessfulCommand(
      "create-groups",
      arguments: ["Models"])

    let testFile = try TestHelpers.createTestFile(
      name: "FallbackFile.swift",
      content: "// Fallback test\n"
    )
    createdTestFiles.append(testFile)

    let targetName =
      extractFirstTarget(from: try TestHelpers.runSuccessfulCommand("list-targets").output)
      ?? "TestApp"

    // Try with non-existent path, even though "Models" exists as simple name
    // This should FAIL because the hierarchical path doesn't resolve
    let result = try TestHelpers.runCommand(
      "add-file",
      arguments: [
        testFile.path,
        "--group", "NonExistent/Path/Models",
        "--targets", targetName,
      ])

    // Should fail - no silent fallback to prevent accidental corruption
    XCTAssertFalse(result.success, "Should fail when hierarchical path doesn't resolve")
    let output = result.output + result.error
    XCTAssertTrue(
      output.contains("not found") || output.contains("Group not found"),
      "Should show group not found error"
    )
  }

  /// Test that invalid path with no fallback fails
  func testAddFileWithInvalidPathAndNoFallback() throws {
    let testFile = try TestHelpers.createTestFile(
      name: "NoFallbackFile.swift",
      content: "// No fallback test\n"
    )
    createdTestFiles.append(testFile)

    let targetName =
      extractFirstTarget(from: try TestHelpers.runSuccessfulCommand("list-targets").output)
      ?? "TestApp"

    // Try with non-existent path where last component also doesn't exist
    let result = try TestHelpers.runCommand(
      "add-file",
      arguments: [
        testFile.path,
        "--group", "NonExistent/Path/Missing",
        "--targets", targetName,
      ])

    // Should fail with helpful error
    XCTAssertFalse(result.success, "Should fail when path and fallback don't exist")
    let errorOutput = result.output + result.error
    XCTAssertTrue(errorOutput.contains("Group not found"), "Should show group not found error")
    XCTAssertTrue(
      errorOutput.contains("list-groups --show-names"),
      "Should suggest using list-groups --show-names"
    )
  }

  // MARK: - Phase 2 Tests: list-groups --show-names

  /// Test that list-groups --show-names shows both formats
  func testListGroupsWithNamesShowsBothFormats() throws {
    // Create a nested group structure
    try TestHelpers.runSuccessfulCommand(
      "create-groups",
      arguments: ["TestApp/Source/Models"])

    // Run list-groups --show-names
    let result = try TestHelpers.runSuccessfulCommand(
      "list-groups",
      arguments: ["--show-names"])

    TestHelpers.assertCommandSuccess(result)

    // Should contain tree structure markers
    XCTAssertTrue(
      result.output.contains("└──") || result.output.contains("├──"),
      "Should show tree structure"
    )

    // Should show format explanation
    XCTAssertTrue(
      result.output.contains("Format:") || result.output.contains("→"),
      "Should explain format"
    )

    // Should show usage information
    XCTAssertTrue(
      result.output.contains("Usage:") || result.output.contains("--group"),
      "Should show usage examples"
    )
  }

  // MARK: - Phase 3 Tests: Edge Cases

  /// Test group operations with special characters
  func testGroupOperationsWithSpecialCharacters() throws {
    // Test group names with spaces
    let result1 = try TestHelpers.runCommand(
      "create-groups",
      arguments: ["My Group With Spaces"])

    // Group names with spaces should work
    XCTAssertTrue(
      result1.success,
      "Should support group names with spaces. Output: \(result1.output)")
  }

  /// Test group operations with very long paths (deeply nested)
  func testGroupOperationsWithVeryLongPaths() throws {
    // Create deeply nested hierarchy (10+ levels)
    let deepPath =
      "Level1/Level2/Level3/Level4/Level5/Level6/Level7/Level8/Level9/Level10/Level11/Level12"
    let result = try TestHelpers.runSuccessfulCommand(
      "create-groups",
      arguments: [deepPath])

    TestHelpers.assertCommandSuccess(result)
    TestHelpers.assertOutputContains(result.output, "Created group")

    // Verify we can add a file to the deepest level
    let testFile = try TestHelpers.createTestFile(
      name: "DeepFile.swift",
      content: "// Deep file\n"
    )
    createdTestFiles.append(testFile)

    let targetName =
      extractFirstTarget(from: try TestHelpers.runSuccessfulCommand("list-targets").output)
      ?? "TestApp"

    let addResult = try TestHelpers.runCommand(
      "add-file",
      arguments: [
        testFile.path,
        "--group", deepPath,
        "--targets", targetName,
      ])

    XCTAssertTrue(addResult.success, "Should be able to add file to deeply nested group")
  }

  /// Test multiple dot filenames
  func testMultipleDotFilenames() throws {
    // Test "Component.test.swift"
    let testFile1 = try TestHelpers.createTestFile(
      name: "File.backup.txt",
      content: "// Backup file\n"
    )
    createdTestFiles.append(testFile1)

    let targetName =
      extractFirstTarget(from: try TestHelpers.runSuccessfulCommand("list-targets").output)
      ?? "TestApp"

    try TestHelpers.runSuccessfulCommand(
      "add-file",
      arguments: [
        testFile1.path,
        "--group", "Sources",
        "--targets", targetName,
      ])

    // "File.backup" group should fail (matches stem)
    let result1 = try TestHelpers.runCommand(
      "create-groups",
      arguments: ["Sources/File.backup"])

    XCTAssertFalse(result1.success, "Should detect collision with 'File.backup' stem")

    // "File" group should succeed (doesn't match)
    let result2 = try TestHelpers.runSuccessfulCommand(
      "create-groups",
      arguments: ["Sources/File"])

    TestHelpers.assertCommandSuccess(result2)
  }

  /// Test hidden files and groups
  func testHiddenFilesAndGroups() throws {
    // Test .swiftpm, .github
    let testFile = try TestHelpers.createTestFile(
      name: ".swiftpm",
      content: "// Swift package manager\n"
    )
    createdTestFiles.append(testFile)

    let targetName =
      extractFirstTarget(from: try TestHelpers.runSuccessfulCommand("list-targets").output)
      ?? "TestApp"

    try TestHelpers.runSuccessfulCommand(
      "add-file",
      arguments: [
        testFile.path,
        "--group", "Sources",
        "--targets", targetName,
      ])

    // ".swiftpm" group should fail
    let result = try TestHelpers.runCommand(
      "create-groups",
      arguments: ["Sources/.swiftpm"])

    XCTAssertFalse(result.success, "Should detect collision with hidden file '.swiftpm'")
  }

  /// Test empty and nil group names handling
  func testEmptyAndNilGroupNames() throws {
    // Test empty group name
    let result1 = try TestHelpers.runCommand(
      "create-groups",
      arguments: [""])

    // Should fail or handle gracefully
    XCTAssertFalse(result1.success, "Should reject empty group name")

    // Test group name with only slashes
    let result2 = try TestHelpers.runCommand(
      "create-groups",
      arguments: ["///"])

    // Should fail or handle gracefully
    XCTAssertFalse(result2.success, "Should reject invalid group path")
  }

  // MARK: - Path Resolution Tests

  /// Test remove-group with hierarchical paths
  func testRemoveGroupWithHierarchicalPath() throws {
    // Create nested group structure
    try TestHelpers.runSuccessfulCommand(
      "create-groups",
      arguments: ["TestApp/Source/Models/TestGroup"])

    // Verify group was created
    let listResult = try TestHelpers.runSuccessfulCommand("list-groups")
    XCTAssertTrue(listResult.output.contains("TestGroup"), "Group should exist")

    // Remove group using hierarchical path
    let removeResult = try TestHelpers.runSuccessfulCommand(
      "remove-group",
      arguments: ["TestApp/Source/Models/TestGroup"])

    TestHelpers.assertCommandSuccess(removeResult)
    TestHelpers.assertOutputContains(removeResult.output, "Removed group")

    // Verify group was removed
    let listResult2 = try TestHelpers.runSuccessfulCommand("list-groups")
    XCTAssertFalse(listResult2.output.contains("TestGroup"), "Group should be removed")
  }

  /// Test list-files with hierarchical paths
  func testListFilesWithHierarchicalPath() throws {
    // Create nested group structure
    try TestHelpers.runSuccessfulCommand(
      "create-groups",
      arguments: ["TestApp/Source/Core"])

    // Add a file to the nested group
    let testFile = try TestHelpers.createTestFile(
      name: "CoreModel.swift",
      content: "// Core model\n"
    )
    createdTestFiles.append(testFile)

    let targetName =
      extractFirstTarget(from: try TestHelpers.runSuccessfulCommand("list-targets").output)
      ?? "TestApp"

    try TestHelpers.runSuccessfulCommand(
      "add-file",
      arguments: [
        testFile.path,
        "--group", "TestApp/Source/Core",
        "--targets", targetName,
      ])

    // List files using hierarchical path
    let listResult = try TestHelpers.runSuccessfulCommand(
      "list-files",
      arguments: ["TestApp/Source/Core"])

    TestHelpers.assertCommandSuccess(listResult)
    TestHelpers.assertOutputContains(listResult.output, "CoreModel.swift")
  }

  /// Test list-files with empty group shows helpful message
  func testListFilesWithEmptyGroup() throws {
    // Create empty group
    try TestHelpers.runSuccessfulCommand(
      "create-groups",
      arguments: ["EmptyTestGroup"])

    // List files in empty group
    let listResult = try TestHelpers.runSuccessfulCommand(
      "list-files",
      arguments: ["EmptyTestGroup"])

    TestHelpers.assertCommandSuccess(listResult)
    TestHelpers.assertOutputContains(listResult.output, "no files")
  }

  /// Test list-files with non-existent group shows error
  func testListFilesWithNonExistentGroup() throws {
    // Try to list files in non-existent group
    let result = try TestHelpers.runCommand(
      "list-files",
      arguments: ["NonExistentGroup12345"])

    XCTAssertFalse(result.success, "Should fail for non-existent group")
    let errorOutput = result.output + result.error
    XCTAssertTrue(
      errorOutput.contains("not found") || errorOutput.contains("Group not found"),
      "Should show group not found error")
  }

  // MARK: - Path Typo Safety Tests

  /// Test remove-group fails with typo in hierarchical path (no silent fallback)
  func testRemoveGroupFailsWithTypoInPath() throws {
    // Create a group structure
    try TestHelpers.runSuccessfulCommand(
      "create-groups",
      arguments: ["TestApp/Source/Models"])

    // Try to remove with typo in path (TestApp/Typo/Models instead of TestApp/Source/Models)
    let result = try TestHelpers.runCommand(
      "remove-group",
      arguments: ["TestApp/Typo/Models"])

    // Should fail, not delete the first "Models" group it finds
    XCTAssertFalse(result.success, "Should fail with incorrect path")
    let errorOutput = result.output + result.error
    XCTAssertTrue(
      errorOutput.contains("not found") || errorOutput.contains("Group not found"),
      "Should show group not found error, not delete wrong group")

    // Verify the original group still exists
    let listResult = try TestHelpers.runSuccessfulCommand("list-groups")
    XCTAssertTrue(listResult.output.contains("Models"), "Original Models group should still exist")
  }

  /// Test add-file fails with typo in hierarchical path (no silent fallback)
  func testAddFileFailsWithTypoInPath() throws {
    // Create a group structure
    try TestHelpers.runSuccessfulCommand(
      "create-groups",
      arguments: ["TestApp/Source/Views"])

    let testFile = try TestHelpers.createTestFile(
      name: "TestView.swift",
      content: "// Test view\n"
    )
    createdTestFiles.append(testFile)

    let targetName =
      extractFirstTarget(from: try TestHelpers.runSuccessfulCommand("list-targets").output)
      ?? "TestApp"

    // Try to add file with typo in path (TestApp/Typo/Views instead of TestApp/Source/Views)
    let result = try TestHelpers.runCommand(
      "add-file",
      arguments: [
        testFile.path,
        "--group", "TestApp/Typo/Views",
        "--targets", targetName,
      ])

    // Should fail, not add to the first "Views" group it finds
    XCTAssertFalse(result.success, "Should fail with incorrect path")
    let errorOutput = result.output + result.error
    XCTAssertTrue(
      errorOutput.contains("not found") || errorOutput.contains("Group not found"),
      "Should show group not found error, not add to wrong group")
  }

  /// Test list-files fails with typo in hierarchical path
  func testListFilesFailsWithTypoInPath() throws {
    // Create a group structure
    try TestHelpers.runSuccessfulCommand(
      "create-groups",
      arguments: ["TestApp/Source/Core"])

    // Try to list with typo in path
    let result = try TestHelpers.runCommand(
      "list-files",
      arguments: ["TestApp/Typo/Core"])

    // Should fail
    XCTAssertFalse(result.success, "Should fail with incorrect path")
    let errorOutput = result.output + result.error
    XCTAssertTrue(
      errorOutput.contains("not found") || errorOutput.contains("Group not found"),
      "Should show group not found error")
  }

  // MARK: - Helper Methods

  /// Extract the first target name from list-targets output
  private func extractFirstTarget(from output: String) -> String? {
    let lines = output.components(separatedBy: .newlines)
    for line in lines {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      // Skip headers and empty lines
      if trimmed.isEmpty || trimmed.hasPrefix("Target") || trimmed.hasPrefix("---")
        || trimmed.hasPrefix("📱")
      {
        continue
      }
      // Extract target name (first word)
      let components = trimmed.components(separatedBy: .whitespaces)
      if let firstComponent = components.first, !firstComponent.isEmpty {
        return firstComponent
      }
    }
    return nil
  }
}
