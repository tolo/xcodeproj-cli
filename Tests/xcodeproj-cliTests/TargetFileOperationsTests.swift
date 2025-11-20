//
// TargetFileOperationsTests.swift
// xcodeproj-cliTests
//
// Tests for add-target-file and remove-target-file commands
//

import XCTest
@testable import xcodeproj_cli

final class TargetFileOperationsTests: XCTProjectTestCase {
  
  var createdTestFiles: [URL] = []
  
  override func setUp() {
    super.setUp()
    createdTestFiles = []
  }
  
  override func tearDown() {
    // Clean up temporary files
    TestHelpers.cleanupTestItems(createdTestFiles)
    createdTestFiles.removeAll()
    super.tearDown()
  }
  
  // MARK: - add-target-file tests
  
  func testAddTargetFileToExistingFile() throws {
    // First add a file to the project with a target
    let sourceFile = try TestHelpers.createTestFile(name: "TestTargetFile.swift", content: "// Test file for target operations")
    createdTestFiles.append(sourceFile)
    
    // Add file to project with target
    var result = try runCommand("add-file", arguments: [
      sourceFile.path, 
      "--group", "Sources",
      "--targets", "TestApp"
    ])
    XCTAssertTrue(result.success, "Failed to add file: \(result.error)")
    
    // Remove the file from the target (but keep in project)
    result = try runCommand("remove-target-file", arguments: [
      "TestTargetFile.swift", "--targets", "TestApp"
    ])
    XCTAssertTrue(result.success, "Failed to remove file from target: \(result.error)")
    
    // Now re-add the file to the target using add-target-file
    result = try runCommand("add-target-file", arguments: [
      "TestTargetFile.swift", "--targets", "TestApp"
    ])
    XCTAssertTrue(result.success, "Failed to add file back to target: \(result.error)")
    
    // Verify file is in project
    result = try runCommand("list-files")
    XCTAssertTrue(result.output.contains("TestTargetFile.swift"))
  }
  
  func testAddTargetFileNonExistentFile() throws {
    let result = try runCommand("add-target-file", arguments: [
      "NonExistent.swift", "--targets", "TestApp"
    ])
    
    XCTAssertFalse(result.success)
    TestHelpers.assertOutputOrErrorContains(result, "not found in project")
  }
  
  // MARK: - remove-target-file tests
  
  func testRemoveTargetFileFromTarget() throws {
    let sourceFile = try TestHelpers.createTestFile(name: "RemovableFile.swift", content: "// File to remove from target")
    createdTestFiles.append(sourceFile)
    
    // Add file with target
    var result = try runCommand("add-file", arguments: [
      sourceFile.path,
      "--group", "Sources", "--targets", "TestApp"
    ])
    XCTAssertTrue(result.success, "Failed to add file: \(result.error)")
    
    // Remove from target only (file should remain in project)
    result = try runCommand("remove-target-file", arguments: [
      "RemovableFile.swift", "--targets", "TestApp"
    ])
    XCTAssertTrue(result.success, "Failed to remove file from target: \(result.error)")
    
    // Verify file still exists in project
    result = try runCommand("list-files")
    XCTAssertTrue(result.output.contains("RemovableFile.swift"), "File should still be in project")
  }
  
  func testRemoveFileCompletelyFromProject() throws {
    let sourceFile = try TestHelpers.createTestFile(name: "TempFile.swift", content: "// Temp file")
    createdTestFiles.append(sourceFile)
    
    // Add file
    var result = try runCommand("add-file", arguments: [
      sourceFile.path,
      "--group", "Sources", "--targets", "TestApp"
    ])
    XCTAssertTrue(result.success, "Failed to add file: \(result.error)")
    
    // Remove completely from project
    result = try runCommand("remove-file", arguments: [
      "TempFile.swift"
    ])
    XCTAssertTrue(result.success, "Failed to remove file: \(result.error)")
    
    // File should be gone from project
    result = try runCommand("list-files")
    XCTAssertFalse(result.output.contains("TempFile.swift"), "File should be removed from project")
  }
  
  // MARK: - Error Scenario Tests
  
  func testAddTargetFileWithNonExistentFile() throws {
    // Try to add a non-existent file to target
    let result = try runCommand("add-target-file", arguments: [
      "NonExistent.swift",
      "--targets", "TestApp"
    ])
    
    TestHelpers.assertCommandFailure(result)
    TestHelpers.assertOutputOrErrorContains(result, "not found")
  }
  
  func testAddTargetFileWithNonExistentTarget() throws {
    // First create a test file and add it to the project
    let testFile = try TestHelpers.createTestFile(name: "ErrorTest.swift", content: "class ErrorTest {}")
    createdTestFiles.append(testFile)
    
    _ = try runSuccessfulCommand("add-file", arguments: [
      testFile.path,
      "--group", "Sources",
      "--targets", "TestApp"
    ])
    
    // Try to add it to a non-existent target
    let result = try runCommand("add-target-file", arguments: [
      "ErrorTest.swift",  // Use just the filename since it's now in the project
      "--targets", "NonExistentTarget"
    ])
    
    TestHelpers.assertCommandFailure(result)
    TestHelpers.assertOutputOrErrorContains(result, "Target not found")
  }
  
  func testAddTargetFileWithoutTargetFlag() throws {
    // Try to add file without specifying target
    let result = try runCommand("add-target-file", arguments: [
      "SomeFile.swift"
    ])

    TestHelpers.assertCommandFailure(result)
    // ArgumentParser validation message
    XCTAssertTrue(
      result.output.contains("Missing expected argument") ||
      result.error.contains("Missing expected argument") ||
      result.output.contains("required") ||
      result.error.contains("required"),
      "Should report missing required flag. Got: \(result.error)"
    )
  }

  func testRemoveTargetFileWithoutTargetFlag() throws {
    // Try to remove file without specifying target
    let result = try runCommand("remove-target-file", arguments: [
      "SomeFile.swift"
    ])

    TestHelpers.assertCommandFailure(result)
    // ArgumentParser validation message
    XCTAssertTrue(
      result.output.contains("Missing expected argument") ||
      result.error.contains("Missing expected argument") ||
      result.output.contains("required") ||
      result.error.contains("required"),
      "Should report missing required flag. Got: \(result.error)"
    )
  }
}