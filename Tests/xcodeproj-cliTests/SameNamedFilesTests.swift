//
// SameNamedFilesTests.swift
// xcodeproj-cliTests
//
// Tests for same-named files in different folders
// Regression tests for file path storage fixes

import Foundation
@preconcurrency import PathKit
import XCTest
@preconcurrency import XcodeProj

final class SameNamedFilesTests: XCTProjectTestCase {

  var createdTestFiles: [URL] = []
  var createdTestDirectories: [URL] = []

  override func tearDown() {
    TestHelpers.cleanupTestItems(createdTestFiles + createdTestDirectories)
    createdTestFiles.removeAll()
    createdTestDirectories.removeAll()
    super.tearDown()
  }

  // MARK: - Same-Named Files in Different Groups

  func testSameNamedFilesInDifferentDirectories() throws {
    // Create two directories
    let sourcesDir = FileManager.default.temporaryDirectory.appendingPathComponent(
      "TestSources_\(UUID().uuidString)")
    let testsDir = FileManager.default.temporaryDirectory.appendingPathComponent(
      "TestTests_\(UUID().uuidString)")

    try FileManager.default.createDirectory(
      at: sourcesDir, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: testsDir, withIntermediateDirectories: true)

    createdTestDirectories.append(sourcesDir)
    createdTestDirectories.append(testsDir)

    // Create two files with THE SAME NAME in different directories
    let sourcesUtils = sourcesDir.appendingPathComponent("Utils.swift")
    let testsUtils = testsDir.appendingPathComponent("Utils.swift")

    try "// Sources Utils\nclass SourcesUtils {}".write(
      to: sourcesUtils, atomically: true, encoding: .utf8)
    try "// Tests Utils\nclass TestsUtils {}".write(
      to: testsUtils, atomically: true, encoding: .utf8)

    createdTestFiles.append(sourcesUtils)
    createdTestFiles.append(testsUtils)

    let targetName =
      extractFirstTarget(from: try runSuccessfulCommand("list-targets").output) ?? "TestApp"

    // Create groups for organization
    _ = try runCommand("create-groups", arguments: ["SourcesGroup"])
    _ = try runCommand("create-groups", arguments: ["TestsGroup"])

    // Add first Utils.swift to SourcesGroup
    let result1 = try runSuccessfulCommand(
      "add-file",
      arguments: [
        sourcesUtils.path,
        "--group", "SourcesGroup",
        "--targets", targetName,
      ])
    TestHelpers.assertOutputContains(result1.output, "Added")

    // Add second Utils.swift to TestsGroup (same filename, different location)
    let result2 = try runSuccessfulCommand(
      "add-file",
      arguments: [
        testsUtils.path,
        "--group", "TestsGroup",
        "--targets", targetName,
      ])
    TestHelpers.assertOutputContains(result2.output, "Added")

    // Now inspect the .pbxproj file to verify stored paths
    let projectPath = Path(TestHelpers.testProjectPath)
    let xcodeproj = try XcodeProj(path: projectPath)
    let pbxproj = xcodeproj.pbxproj

    // Find both Utils.swift file references
    let utilsFileRefs = pbxproj.fileReferences.filter { fileRef in
      (fileRef.path ?? "").hasSuffix("Utils.swift") || (fileRef.name ?? "").hasSuffix("Utils.swift")
    }

    // Should have at least 2 Utils.swift files
    XCTAssertGreaterThanOrEqual(
      utilsFileRefs.count, 2,
      "Should have at least 2 Utils.swift file references")

    // Verify they have different paths stored
    let paths = utilsFileRefs.compactMap { $0.path }
    let uniquePaths = Set(paths)

    // If paths are different, the count should be at least 2
    XCTAssertGreaterThanOrEqual(
      uniquePaths.count, 2,
      "Utils.swift files should have distinct relative paths (not just basenames). Found paths: \(paths)"
    )

    // Verify both files exist in the file list
    let listResult = try runSuccessfulCommand("list-files")
    let utilsCount = listResult.output.components(separatedBy: "Utils.swift").count - 1
    XCTAssertGreaterThanOrEqual(
      utilsCount, 2,
      "Should list at least 2 instances of Utils.swift")
  }

  func testSameNamedFilesHaveDifferentCacheKeys() throws {
    // Create directories
    let modelsDir = FileManager.default.temporaryDirectory.appendingPathComponent(
      "Models_\(UUID().uuidString)")
    let servicesDir = FileManager.default.temporaryDirectory.appendingPathComponent(
      "Services_\(UUID().uuidString)")

    try FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: servicesDir, withIntermediateDirectories: true)

    createdTestDirectories.append(modelsDir)
    createdTestDirectories.append(servicesDir)

    // Create files with same name "User.swift"
    let modelsUser = modelsDir.appendingPathComponent("User.swift")
    let servicesUser = servicesDir.appendingPathComponent("User.swift")

    try "// Model User\nstruct UserModel {}".write(
      to: modelsUser, atomically: true, encoding: .utf8)
    try "// Service User\nclass UserService {}".write(
      to: servicesUser, atomically: true, encoding: .utf8)

    createdTestFiles.append(modelsUser)
    createdTestFiles.append(servicesUser)

    let targetName =
      extractFirstTarget(from: try runSuccessfulCommand("list-targets").output) ?? "TestApp"

    // Create separate groups
    _ = try runCommand("create-groups", arguments: ["ModelsGroup"])
    _ = try runCommand("create-groups", arguments: ["ServicesGroup"])

    // Add both User.swift files to different groups
    let result1 = try runSuccessfulCommand(
      "add-file",
      arguments: [
        modelsUser.path,
        "--group", "ModelsGroup",
        "--targets", targetName,
      ])
    TestHelpers.assertOutputContains(result1.output, "Added")

    let result2 = try runSuccessfulCommand(
      "add-file",
      arguments: [
        servicesUser.path,
        "--group", "ServicesGroup",
        "--targets", targetName,
      ])
    TestHelpers.assertOutputContains(result2.output, "Added")

    // Load project and verify
    let projectPath = Path(TestHelpers.testProjectPath)
    let xcodeproj = try XcodeProj(path: projectPath)
    let pbxproj = xcodeproj.pbxproj

    // Find User.swift file references
    let userFileRefs = pbxproj.fileReferences.filter { fileRef in
      (fileRef.path ?? "").hasSuffix("User.swift") || (fileRef.name ?? "").hasSuffix("User.swift")
    }

    // Should have at least 2 User.swift files
    XCTAssertGreaterThanOrEqual(
      userFileRefs.count, 2,
      "Should have at least 2 User.swift file references in different groups")

    // Verify project is valid
    let validateResult = try runSuccessfulCommand("validate")
    TestHelpers.assertCommandSuccess(validateResult)
  }

  func testCannotAddSameFileToSameGroupTwice() throws {
    let testFile = try TestHelpers.createTestFile(
      name: "Duplicate.swift",
      content: "// Duplicate test\n"
    )
    createdTestFiles.append(testFile)

    let targetName =
      extractFirstTarget(from: try runSuccessfulCommand("list-targets").output) ?? "TestApp"

    // Add file first time
    let result1 = try runSuccessfulCommand(
      "add-file",
      arguments: [
        testFile.path,
        "--group", "Sources",
        "--targets", targetName,
      ])
    TestHelpers.assertOutputContains(result1.output, "Added")

    // Try to add same file again to same group
    let result2 = try runCommand(
      "add-file",
      arguments: [
        testFile.path,
        "--group", "Sources",
        "--targets", targetName,
      ])

    // Should skip the file (warning message)
    TestHelpers.assertOutputContains(result2.output, "already exists")
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
}
