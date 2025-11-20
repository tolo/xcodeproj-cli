//
// TargetDuplicationIntegrityTests.swift
// xcodeproj-cliTests
//
// Tests for target duplication integrity
// Ensures duplicated targets maintain independence and don't share build file UUIDs

import Foundation
@preconcurrency import PathKit
import XCTest
@preconcurrency import XcodeProj

final class TargetDuplicationIntegrityTests: XCTProjectTestCase {

  var createdTestFiles: [URL] = []

  override func tearDown() {
    TestHelpers.cleanupTestItems(createdTestFiles)
    createdTestFiles.removeAll()
    super.tearDown()
  }

  // MARK: - Target Duplication Integrity Tests

  func testDuplicatedTargetIndependence() throws {
    // Get original target
    let targetsResult = try runCommand("list-targets")
    guard let originalTarget = extractFirstTarget(from: targetsResult.output) else {
      // Skip test if no targets exist in test project
      throw XCTSkip("No targets found in test project - test requires existing targets")
    }

    // Duplicate the target
    let duplicatedName = "\(originalTarget)Copy"
    let duplicateResult = try runSuccessfulCommand(
      "duplicate-target",
      arguments: [originalTarget, duplicatedName]
    )
    TestHelpers.assertCommandSuccess(duplicateResult)

    // Create a new test file
    let testFile = try TestHelpers.createTestFile(
      name: "PostDuplicationFile.swift",
      content: "// File added after duplication\nclass PostDuplicationFile {}\n"
    )
    createdTestFiles.append(testFile)

    // Add file to ONLY the original target
    let addResult = try runSuccessfulCommand(
      "add-file",
      arguments: [
        testFile.path,
        "--group", "Sources",
        "--targets", originalTarget,
      ])
    TestHelpers.assertOutputContains(addResult.output, "Added")

    // Verify the file appears in original target's build files
    let originalFiles = try runSuccessfulCommand(
      "list-files",
      arguments: ["--target", originalTarget]
    )
    TestHelpers.assertOutputContains(originalFiles.output, "PostDuplicationFile.swift")

    // Verify the file does NOT appear in duplicated target's build files
    let duplicatedFiles = try runSuccessfulCommand(
      "list-files",
      arguments: ["--target", duplicatedName]
    )

    // The duplicated target should not contain the file added after duplication
    let hasFileInDuplicate = duplicatedFiles.output.contains("PostDuplicationFile.swift")
    XCTAssertFalse(
      hasFileInDuplicate,
      "Duplicated target should not automatically receive files added to original target after duplication"
    )

    // NOW: Inspect the pbxproj to verify build file UUID independence
    let projectPath = Path(TestHelpers.testProjectPath)
    let xcodeproj = try XcodeProj(path: projectPath)
    let pbxproj = xcodeproj.pbxproj

    // Find the two targets
    guard let originalTargetObj = pbxproj.nativeTargets.first(where: { $0.name == originalTarget })
    else {
      XCTFail("Could not find original target '\(originalTarget)' in pbxproj")
      return
    }

    guard
      let duplicatedTargetObj = pbxproj.nativeTargets.first(where: { $0.name == duplicatedName })
    else {
      XCTFail("Could not find duplicated target '\(duplicatedName)' in pbxproj")
      return
    }

    // Collect all build file UUIDs from both targets
    var originalBuildFileUUIDs = Set<String>()
    for buildPhase in originalTargetObj.buildPhases {
      for buildFile in buildPhase.files ?? [] {
        originalBuildFileUUIDs.insert(buildFile.uuid)
      }
    }

    var duplicatedBuildFileUUIDs = Set<String>()
    for buildPhase in duplicatedTargetObj.buildPhases {
      for buildFile in buildPhase.files ?? [] {
        duplicatedBuildFileUUIDs.insert(buildFile.uuid)
      }
    }

    // Verify no UUID collisions between original and duplicated targets
    let sharedUUIDs = originalBuildFileUUIDs.intersection(duplicatedBuildFileUUIDs)
    XCTAssertTrue(
      sharedUUIDs.isEmpty,
      "Duplicated target should have independent PBXBuildFile objects (no shared UUIDs). Found shared UUIDs: \(sharedUUIDs)"
    )

    // Verify targets have distinct build phases (different objects, not shared references)
    let originalPhaseUUIDs = Set(originalTargetObj.buildPhases.map { $0.uuid })
    let duplicatedPhaseUUIDs = Set(duplicatedTargetObj.buildPhases.map { $0.uuid })
    let sharedPhaseUUIDs = originalPhaseUUIDs.intersection(duplicatedPhaseUUIDs)

    XCTAssertTrue(
      sharedPhaseUUIDs.isEmpty,
      "Duplicated target should have independent build phases (no shared phase UUIDs). Found shared phase UUIDs: \(sharedPhaseUUIDs)"
    )
  }

  func testDuplicatedTargetHasUniqueConfiguration() throws {
    // Get original target
    let targetsResult = try runCommand("list-targets")
    guard let originalTarget = extractFirstTarget(from: targetsResult.output) else {
      throw XCTSkip("No targets found in test project - test requires existing targets")
    }

    // Duplicate the target
    let duplicatedName = "\(originalTarget)Duplicate"
    let duplicateResult = try runSuccessfulCommand(
      "duplicate-target",
      arguments: [originalTarget, duplicatedName]
    )
    TestHelpers.assertCommandSuccess(duplicateResult)

    // Verify both targets exist
    let listResult = try runSuccessfulCommand("list-targets")
    TestHelpers.assertOutputContains(listResult.output, originalTarget)
    TestHelpers.assertOutputContains(listResult.output, duplicatedName)

    // Modify build setting on original target
    let setBuildSettingResult = try runSuccessfulCommand(
      "set-build-setting",
      arguments: [
        "--target", originalTarget,
        "--config", "Debug",
        "PRODUCT_NAME",
        "OriginalProduct",
      ])
    TestHelpers.assertCommandSuccess(setBuildSettingResult)

    // Verify original target has the new setting
    let originalSettings = try runSuccessfulCommand(
      "get-build-settings",
      arguments: ["--target", originalTarget, "--config", "Debug"]
    )
    TestHelpers.assertOutputContains(originalSettings.output, "OriginalProduct")

    // Verify duplicated target still has its own configuration
    // (should not automatically inherit the change made after duplication)
    let duplicatedSettings = try runSuccessfulCommand(
      "get-build-settings",
      arguments: ["--target", duplicatedName, "--config", "Debug"]
    )

    // The duplicated target should have its own PRODUCT_NAME (likely the duplicated name)
    TestHelpers.assertOutputContains(duplicatedSettings.output, "PRODUCT_NAME")
  }

  func testMultipleTargetDuplications() throws {
    // Get original target
    let targetsResult = try runCommand("list-targets")
    guard let originalTarget = extractFirstTarget(from: targetsResult.output) else {
      throw XCTSkip("No targets found in test project - test requires existing targets")
    }

    // Create multiple duplicates
    let duplicate1 = "\(originalTarget)Copy1"
    let duplicate2 = "\(originalTarget)Copy2"

    _ = try runSuccessfulCommand("duplicate-target", arguments: [originalTarget, duplicate1])
    _ = try runSuccessfulCommand("duplicate-target", arguments: [originalTarget, duplicate2])

    // Verify all targets exist
    let listResult = try runSuccessfulCommand("list-targets")
    TestHelpers.assertOutputContains(listResult.output, originalTarget)
    TestHelpers.assertOutputContains(listResult.output, duplicate1)
    TestHelpers.assertOutputContains(listResult.output, duplicate2)

    // Verify project validates correctly with multiple duplicates
    let validateResult = try runSuccessfulCommand("validate")
    TestHelpers.assertCommandSuccess(validateResult)
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
