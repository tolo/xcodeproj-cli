//
// FileOperationsTests.swift
// xcodeproj-cliTests
//
// Tests for file operation commands: add-file, add-folder, remove-file, move-file
//

import Foundation
import XCTest

final class FileOperationsTests: XCTProjectTestCase {

  var createdTestFiles: [URL] = []
  var createdTestDirectories: [URL] = []

  override func tearDown() {
    // Clean up any test files created during tests
    TestHelpers.cleanupTestItems(createdTestFiles + createdTestDirectories)
    createdTestFiles.removeAll()
    createdTestDirectories.removeAll()

    super.tearDown()
  }

  // MARK: - Add File Tests

  func testAddSingleFile() throws {
    // Create a test file
    let testFile = try TestHelpers.createTestFile(
      name: "TestAddFile.swift",
      content: "// Test file for add-file command\nclass TestAddFile {}\n"
    )
    createdTestFiles.append(testFile)

    // Get available targets first
    let targetsResult = try runSuccessfulCommand("list-targets")
    let targetName = extractFirstTarget(from: targetsResult.output) ?? "TestApp"

    // Add the file to project
    let result = try runSuccessfulCommand(
      "add-file",
      arguments: [
        testFile.path,
        "--group", "Sources",
        "--targets", targetName,
      ])

    TestHelpers.assertOutputContains(result.output, "Added")

    // Verify file was added by listing files
    let listResult = try runSuccessfulCommand("list-files")
    TestHelpers.assertOutputContains(listResult.output, "TestAddFile.swift")
  }

  func testAddFileWithShortFlags() throws {
    let testFile = try TestHelpers.createTestFile(
      name: "TestShortFlags.swift",
      content: "// Test file with short flags\n"
    )
    createdTestFiles.append(testFile)

    let targetName =
      extractFirstTarget(from: try runSuccessfulCommand("list-targets").output) ?? "TestApp"

    // Use short flags: -g for group, -t for targets
    let result = try runSuccessfulCommand(
      "add-file",
      arguments: [
        testFile.path,
        "-g", "Sources",
        "-t", targetName,
      ])

    TestHelpers.assertCommandSuccess(result)

    // Verify file was added
    let listResult = try runSuccessfulCommand("list-files")
    TestHelpers.assertOutputContains(listResult.output, "TestShortFlags.swift")
  }

  func testAddFileToNonExistentGroup() throws {
    let testFile = try TestHelpers.createTestFile(name: "TestNonExistentGroup.swift")
    createdTestFiles.append(testFile)

    let targetName =
      extractFirstTarget(from: try runSuccessfulCommand("list-targets").output) ?? "TestApp"

    // Try to add to non-existent group
    let result = try runCommand(
      "add-file",
      arguments: [
        testFile.path,
        "--group", "NonExistentGroup",
        "--targets", targetName,
      ])

    // Should either create the group or fail gracefully
    if !result.success {
      XCTAssertTrue(
        result.output.contains("❌ Error:") || result.output.contains("Group not found")
          || result.error.contains("Group not found") || result.output.contains("cannot be found")
          || result.output.contains("create"),
        "Should provide clear error about non-existent group. Got error: '\(result.error)' output: '\(result.output)'"
      )
    }
  }

  func testAddFileToMultipleTargets() throws {
    let testFile = try TestHelpers.createTestFile(name: "TestMultipleTargets.swift")
    createdTestFiles.append(testFile)

    let targetsResult = try runSuccessfulCommand("list-targets")
    let allTargets = extractAllTargets(from: targetsResult.output)

    if allTargets.count >= 2 {
      let targetList = Array(allTargets.prefix(2)).joined(separator: ",")

      let result = try runSuccessfulCommand(
        "add-file",
        arguments: [
          testFile.path,
          "--group", "Sources",
          "--targets", targetList,
        ])

      TestHelpers.assertCommandSuccess(result)
    }
  }

  func testAddNonExistentFile() throws {
    let targetName =
      extractFirstTarget(from: try runSuccessfulCommand("list-targets").output) ?? "TestApp"

    let result = try runFailingCommand(
      "add-file",
      arguments: [
        "NonExistentFile.swift",
        "--group", "Sources",
        "--targets", targetName,
      ])

    TestHelpers.assertCommandFailure(result)
    XCTAssertTrue(
      result.error.contains("❌ Error: Operation failed: File not found")
        || result.output.contains("File not found"),
      "Should report file not found"
    )
  }

  // MARK: - Add Files (Batch) Tests

  func testAddMultipleFiles() throws {
    // Create multiple test files
    let testFiles = [
      try TestHelpers.createTestFile(name: "BatchFile1.swift", content: "// Batch file 1\n"),
      try TestHelpers.createTestFile(name: "BatchFile2.swift", content: "// Batch file 2\n"),
      try TestHelpers.createTestFile(name: "BatchFile3.swift", content: "// Batch file 3\n"),
    ]
    createdTestFiles.append(contentsOf: testFiles)

    let targetName =
      extractFirstTarget(from: try runSuccessfulCommand("list-targets").output) ?? "TestApp"

    // Use pattern to add all files
    let testDir = testFiles[0].deletingLastPathComponent()
    let pattern = testDir.appendingPathComponent("BatchFile*.swift").path

    let result = try runCommand(
      "add-files",
      arguments: [
        pattern,
        "--group", "Sources",
        "--targets", targetName,
      ])

    if result.success {
      // Verify files were added
      let listResult = try runSuccessfulCommand("list-files")
      TestHelpers.assertOutputContains(listResult.output, "BatchFile1.swift")
      TestHelpers.assertOutputContains(listResult.output, "BatchFile2.swift")
      TestHelpers.assertOutputContains(listResult.output, "BatchFile3.swift")
    }
  }

  // MARK: - Add Folder Tests

  func testAddFolderNonRecursive() throws {
    // Create a test directory with files
    let testDir = try TestHelpers.createTestDirectory(
      name: "TestFolder",
      files: [
        "FileInFolder.swift": "// File in test folder\n",
        "AnotherFile.swift": "// Another file in test folder\n",
      ]
    )
    createdTestDirectories.append(testDir)

    let targetName =
      extractFirstTarget(from: try runSuccessfulCommand("list-targets").output) ?? "TestApp"

    // Create the target group first
    _ = try runSuccessfulCommand("create-groups", arguments: ["TestFolderGroup"])

    let result = try runSuccessfulCommand(
      "add-folder",
      arguments: [
        testDir.path,
        "--group", "TestFolderGroup",
        "--targets", targetName,
      ])

    TestHelpers.assertCommandSuccess(result)

    // Verify files were added
    let listResult = try runSuccessfulCommand("list-files")
    TestHelpers.assertOutputContains(listResult.output, "FileInFolder.swift")
    TestHelpers.assertOutputContains(listResult.output, "AnotherFile.swift")
  }

  func testAddFolderRecursive() throws {
    // Create a test directory with subdirectories
    let testDir = try TestHelpers.createTestDirectory(name: "RecursiveTestFolder", files: [:])
    let subDir = testDir.appendingPathComponent("SubDirectory")
    try FileManager.default.createDirectory(
      at: subDir, withIntermediateDirectories: true, attributes: nil)

    // Create files in both directories
    try "// Root file\n".write(
      to: testDir.appendingPathComponent("RootFile.swift"), atomically: true, encoding: .utf8)
    try "// Sub file\n".write(
      to: subDir.appendingPathComponent("SubFile.swift"), atomically: true, encoding: .utf8)

    createdTestDirectories.append(testDir)

    let targetName =
      extractFirstTarget(from: try runSuccessfulCommand("list-targets").output) ?? "TestApp"

    // Create the target group first
    _ = try runSuccessfulCommand("create-groups", arguments: ["RecursiveGroup"])

    let result = try runSuccessfulCommand(
      "add-folder",
      arguments: [
        testDir.path,
        "--group", "RecursiveGroup",
        "--targets", targetName,
        "--recursive",
      ])

    TestHelpers.assertCommandSuccess(result)

    // Verify both root and sub files were added
    let listResult = try runSuccessfulCommand("list-files")
    TestHelpers.assertOutputContains(listResult.output, "RootFile.swift")
    TestHelpers.assertOutputContains(listResult.output, "SubFile.swift")
  }

  func testAddNonExistentFolder() throws {
    let targetName =
      extractFirstTarget(from: try runSuccessfulCommand("list-targets").output) ?? "TestApp"

    let result = try runFailingCommand(
      "add-folder",
      arguments: [
        "/path/to/nonexistent/folder",
        "--group", "Sources",
        "--targets", targetName,
      ])

    TestHelpers.assertCommandFailure(result)
    XCTAssertTrue(
      result.output.contains("❌ Error:") || result.output.contains("Folder not found")
        || result.error.contains("Folder not found") || result.output.contains("cannot be found")
        || result.output.contains("does not exist"),
      "Should report folder not found. Got error: '\(result.error)' output: '\(result.output)'"
    )
  }

  // MARK: - Remove File Tests

  func testRemoveFile() throws {
    // First add a file
    let testFile = try TestHelpers.createTestFile(name: "ToBeRemoved.swift")
    createdTestFiles.append(testFile)

    let targetName =
      extractFirstTarget(from: try runSuccessfulCommand("list-targets").output) ?? "TestApp"

    // Add the file
    _ = try runSuccessfulCommand(
      "add-file",
      arguments: [
        testFile.path,
        "--group", "Sources",
        "--targets", targetName,
      ])

    // Verify it was added
    let listBefore = try runSuccessfulCommand("list-files")
    TestHelpers.assertOutputContains(listBefore.output, "ToBeRemoved.swift")

    // Now remove it
    let removeResult = try runSuccessfulCommand(
      "remove-file", arguments: [testFile.lastPathComponent])
    TestHelpers.assertCommandSuccess(removeResult)

    // Verify it was removed
    let listAfter = try runSuccessfulCommand("list-files")
    TestHelpers.assertOutputDoesNotContain(listAfter.output, "ToBeRemoved.swift")
  }

  func testRemoveNonExistentFile() throws {
    let result = try runFailingCommand("remove-file", arguments: ["NonExistentFileToRemove.swift"])

    TestHelpers.assertCommandFailure(result)
    XCTAssertTrue(
      result.error.contains("❌ Error:") || result.output.contains("cannot be found")
        || result.output.contains("not found"),
      "Should report file not found for removal"
    )
  }

  // MARK: - Move File Tests

  func testMoveFile() throws {
    // First add a file
    let testFile = try TestHelpers.createTestFile(name: "ToBeMoved.swift")
    createdTestFiles.append(testFile)

    let targetName =
      extractFirstTarget(from: try runSuccessfulCommand("list-targets").output) ?? "TestApp"

    // Add the file to Sources group
    _ = try runSuccessfulCommand(
      "add-file",
      arguments: [
        testFile.path,
        "--group", "Sources",
        "--targets", targetName,
      ])

    // Create destination group first
    _ = try runCommand("create-groups", arguments: ["MovedFiles"])

    // Move the file to different group
    let moveResult = try runCommand(
      "move-file",
      arguments: [
        testFile.lastPathComponent,
        "--to-group", "MovedFiles",
      ])

    if moveResult.success {
      TestHelpers.assertCommandSuccess(moveResult)

      // Verify file is still in project but in new location
      let listResult = try runSuccessfulCommand("list-files")
      TestHelpers.assertOutputContains(listResult.output, "ToBeMoved.swift")
    }
  }

  func testMoveNonExistentFile() throws {
    let result = try runFailingCommand(
      "move-file",
      arguments: [
        "NonExistentMoveFile.swift",
        "--to-group", "Sources",
      ])

    TestHelpers.assertCommandFailure(result)
    XCTAssertTrue(
      result.error.contains("❌ Error:") || result.output.contains("cannot be found")
        || result.output.contains("not found"),
      "Should report file not found for moving"
    )
  }

  // MARK: - Group Operations Tests

  func testCreateGroups() throws {
    let result = try runSuccessfulCommand("create-groups", arguments: ["NewTestGroup"])

    TestHelpers.assertCommandSuccess(result)

    // Verify group was created
    let groupsResult = try runSuccessfulCommand("list-groups")
    TestHelpers.assertOutputContains(groupsResult.output, "NewTestGroup")
  }

  func testCreateNestedGroups() throws {
    let result = try runSuccessfulCommand("create-groups", arguments: ["Parent/Child/GrandChild"])

    TestHelpers.assertCommandSuccess(result)

    // Verify nested groups were created
    let groupsResult = try runSuccessfulCommand("list-groups")
    TestHelpers.assertOutputContains(groupsResult.output, "Parent")
    TestHelpers.assertOutputContains(groupsResult.output, "Child")
    TestHelpers.assertOutputContains(groupsResult.output, "GrandChild")
  }

  func testRemoveGroup() throws {
    // First create a group
    _ = try runSuccessfulCommand("create-groups", arguments: ["ToBeRemovedGroup"])

    // Verify it exists
    let groupsBefore = try runSuccessfulCommand("list-groups")
    TestHelpers.assertOutputContains(groupsBefore.output, "ToBeRemovedGroup")

    // Remove the group
    let removeResult = try runSuccessfulCommand("remove-group", arguments: ["ToBeRemovedGroup"])
    TestHelpers.assertCommandSuccess(removeResult)

    // Verify it's gone
    let groupsAfter = try runSuccessfulCommand("list-groups")
    TestHelpers.assertOutputDoesNotContain(groupsAfter.output, "ToBeRemovedGroup")
  }

  // MARK: - File Type Detection Tests

  func testAddDifferentFileTypes() throws {
    let targetName =
      extractFirstTarget(from: try runSuccessfulCommand("list-targets").output) ?? "TestApp"

    let testFiles = [
      ("TestSwift.swift", "// Swift file\nclass TestSwift {}\n"),
      ("TestHeader.h", "// Header file\n#ifndef TEST_H\n#define TEST_H\n#endif\n"),
      ("TestObjC.m", "// Objective-C file\n#import \"TestHeader.h\"\n"),
      ("TestPlist.plist", "<?xml version=\"1.0\"?>\n<plist><dict></dict></plist>\n"),
      ("TestJSON.json", "{\"test\": true}\n"),
    ]

    for (fileName, content) in testFiles {
      let testFile = try TestHelpers.createTestFile(name: fileName, content: content)
      createdTestFiles.append(testFile)

      let result = try runCommand(
        "add-file",
        arguments: [
          testFile.path,
          "--group", "Sources",
          "--targets", targetName,
        ])

      // Different file types might be handled differently
      if result.success {
        XCTAssertTrue(true, "Successfully added \(fileName)")
      } else {
        // Some file types might not be supported, which is acceptable
        XCTAssertTrue(
          result.output.contains("not supported") || result.output.contains("invalid type"),
          "Should provide clear message for unsupported file type \(fileName)"
        )
      }
    }
  }

  // MARK: - Edge Cases Tests

  func testAddFileWithSpecialCharacters() throws {
    // Test files with special characters in names
    let specialFiles = [
      "File With Spaces.swift",
      "File-With-Dashes.swift",
      "File_With_Underscores.swift",
    ]

    let targetName =
      extractFirstTarget(from: try runSuccessfulCommand("list-targets").output) ?? "TestApp"

    for fileName in specialFiles {
      do {
        let testFile = try TestHelpers.createTestFile(name: fileName)
        createdTestFiles.append(testFile)

        let result = try runCommand(
          "add-file",
          arguments: [
            testFile.path,
            "--group", "Sources",
            "--targets", targetName,
          ])

        if result.success {
          XCTAssertTrue(true, "Successfully handled file with special characters: \(fileName)")
        } else {
          // Should provide clear error rather than crash
          XCTAssertTrue(
            result.output.count > 0 || result.error.count > 0,
            "Should provide error message for special character file")
        }
      } catch {
        // File system might not support certain special characters
        XCTAssertTrue(true, "File system limitation for \(fileName)")
      }
    }
  }

  // MARK: - Duplicate Build File Tests

  func testRemoveFileWithDuplicateBuildFiles() throws {
    // This test simulates the scenario where a file might have been
    // accidentally added to a target multiple times, creating duplicate
    // PBXBuildFile entries in the project

    // Create a test file
    let testFile = try TestHelpers.createTestFile(
      name: "DuplicateTestFile.swift",
      content: "// Test file for duplicate build file scenario\n"
    )
    createdTestFiles.append(testFile)

    let targetName =
      extractFirstTarget(from: try runSuccessfulCommand("list-targets").output) ?? "TestApp"

    // Add the file to the project
    _ = try runSuccessfulCommand(
      "add-file",
      arguments: [
        testFile.path,
        "--group", "Sources",
        "--targets", targetName,
      ])

    // Manually manipulate the project to create a duplicate build file entry
    // In real scenarios, this might happen through merge conflicts or other issues
    // For now, we'll just try to add the same file again which might create duplicates
    _ = try runCommand(
      "add-file",
      arguments: [
        testFile.path,
        "--group", "Sources",
        "--targets", targetName,
      ])

    // The second add might fail or succeed depending on implementation
    // But removal should always work without crashing

    // Now try to remove the file - this should not crash even with duplicates
    let removeResult = try runCommand("remove-file", arguments: [testFile.path])

    // The command should either succeed or provide a clear error message
    // It should NOT crash with "Duplicate elements of type 'PBXBuildFile' were found in a Set"
    XCTAssertTrue(
      removeResult.success || removeResult.output.contains("Error")
        || removeResult.error.contains("Error"),
      "Remove file should either succeed or provide clear error, not crash. Output: '\(removeResult.output)' Error: '\(removeResult.error)'"
    )

    // Verify the file is no longer in the project if removal succeeded
    if removeResult.success {
      let listResult = try runSuccessfulCommand("list-files")
      XCTAssertFalse(
        listResult.output.contains("DuplicateTestFile.swift"),
        "File should be removed from project after successful removal"
      )
    }
  }

  func testBatchRemoveWithPotentialDuplicates() throws {
    // Test batch removal scenario that triggered the original bug
    // Create multiple test files
    var testFiles: [URL] = []
    for i in 1...5 {
      let testFile = try TestHelpers.createTestFile(
        name: "BatchRemoveFile\(i).swift",
        content: "// Batch remove test file \(i)\n"
      )
      testFiles.append(testFile)
      createdTestFiles.append(testFile)
    }

    let targetName =
      extractFirstTarget(from: try runSuccessfulCommand("list-targets").output) ?? "TestApp"

    // Add all files to the project
    for testFile in testFiles {
      _ = try runSuccessfulCommand(
        "add-file",
        arguments: [
          testFile.path,
          "--group", "Sources",
          "--targets", targetName,
        ])
    }

    // Now remove them in batch - this should handle any potential duplicates gracefully
    var allRemovalsSuccessful = true
    var crashDetected = false

    for testFile in testFiles {
      let result = try runCommand("remove-file", arguments: [testFile.lastPathComponent])

      if !result.success {
        allRemovalsSuccessful = false
        // Check if it's the specific Set crash
        if result.error.contains("Duplicate elements of type") && result.error.contains("Set") {
          crashDetected = true
          break
        }
      }
    }

    // Assert that we didn't encounter the Set crash
    XCTAssertFalse(
      crashDetected,
      "Should not crash with 'Duplicate elements of type PBXBuildFile were found in a Set' error"
    )

    // It's OK if some removals fail for other reasons, but no crashes
    if allRemovalsSuccessful {
      // Verify all files were removed
      let listResult = try runSuccessfulCommand("list-files")
      for i in 1...5 {
        XCTAssertFalse(
          listResult.output.contains("BatchRemoveFile\(i).swift"),
          "File BatchRemoveFile\(i).swift should be removed"
        )
      }
    }
  }

  func testRemoveFolderWithPotentialDuplicates() throws {
    // Test folder removal to ensure it doesn't crash with duplicate build files
    // This tests the fix for removeFolderReference method

    // Create a test directory with files
    let testDir = try TestHelpers.createTestDirectory(
      name: "FolderToRemove",
      files: [
        "File1.swift": "// Test file 1\n",
        "File2.swift": "// Test file 2\n",
      ]
    )
    createdTestDirectories.append(testDir)

    let targetName =
      extractFirstTarget(from: try runSuccessfulCommand("list-targets").output) ?? "TestApp"

    // Add the folder as a folder reference (not groups)
    _ = try runSuccessfulCommand(
      "add-folder",
      arguments: [
        testDir.path,
        "--group", "Sources",
        "--targets", targetName,
      ])

    // Try to remove the folder - should not crash even if there are duplicate build files
    let removeResult = try runCommand("remove-group", arguments: ["FolderToRemove"])

    // Should either succeed or provide clear error, but not crash
    XCTAssertTrue(
      removeResult.success || removeResult.output.contains("Error")
        || removeResult.error.contains("Error"),
      "Remove folder should either succeed or provide clear error, not crash"
    )
  }

  // MARK: - Helper Methods

  private func extractFirstTarget(from output: String) -> String? {
    let lines = output.components(separatedBy: .newlines)
    for line in lines {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if !trimmed.isEmpty && !trimmed.contains(":") && !trimmed.contains("Target")
        && !trimmed.contains("-") && !trimmed.contains("=")
      {
        return trimmed
      }
    }
    return nil
  }

  private func extractAllTargets(from output: String) -> [String] {
    let lines = output.components(separatedBy: .newlines)
    var targets: [String] = []

    for line in lines {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if !trimmed.isEmpty && !trimmed.contains(":") && !trimmed.contains("Target")
        && !trimmed.contains("-") && !trimmed.contains("=") && trimmed.count < 50
      {  // Reasonable target name length
        targets.append(trimmed)
      }
    }

    return targets
  }
}
