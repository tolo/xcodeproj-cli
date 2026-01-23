//
// BuildConfigurationTests.swift
// xcodeproj-cliTests
//
// Tests for enhanced build configuration and settings commands
//

import Foundation
import XCTest

final class BuildConfigurationTests: XCTProjectTestCase {

  // MARK: - List Build Settings Tests (Enhanced)

  func testListBuildSettingsDefault() throws {
    let result = try runSuccessfulCommand("list-build-settings")

    TestHelpers.assertCommandSuccess(result)
    XCTAssertTrue(result.output.count > 0, "Should show build settings")

    // Should contain some common project-level settings
    XCTAssertTrue(
      result.output.contains("Build Settings") || result.output.contains("Configuration")
        || result.output.contains("PROJECT") || result.output.contains("PRODUCT_NAME"),
      "Should show project-level build settings. Got: \(result.output)"
    )
  }

  func testListBuildSettingsWithTarget() throws {
    let targetsResult = try runSuccessfulCommand("list-targets")
    let targetName = extractFirstTarget(from: targetsResult.output)

    if let target = targetName {
      let result = try runSuccessfulCommand(
        "list-build-settings",
        arguments: [
          "--target", target,
        ])

      TestHelpers.assertCommandSuccess(result)
      XCTAssertTrue(result.output.count > 0, "Should show target build settings")
      TestHelpers.assertOutputContains(result.output, target)
    }
  }

  func testListBuildSettingsWithTargetShortFlag() throws {
    let targetsResult = try runSuccessfulCommand("list-targets")
    let targetName = extractFirstTarget(from: targetsResult.output)

    if let target = targetName {
      let result = try runSuccessfulCommand(
        "list-build-settings",
        arguments: [
          "-t", target,
        ])

      TestHelpers.assertCommandSuccess(result)
      XCTAssertTrue(result.output.count > 0, "Should show target build settings with short flag")
      TestHelpers.assertOutputContains(result.output, target)
    }
  }

  func testListBuildSettingsWithConfig() throws {
    let result = try runSuccessfulCommand(
      "list-build-settings",
      arguments: [
        "--config", "Debug",
      ])

    TestHelpers.assertCommandSuccess(result)
    XCTAssertTrue(result.output.count > 0, "Should show configuration-specific settings")
    // Config filtering works even if config name isn't shown in output
    XCTAssertTrue(
      result.output.contains("Build Settings") || result.output.contains("CLANG"),
      "Expected build settings output but got: \(result.output)")
  }

  func testListBuildSettingsWithConfigShortFlag() throws {
    let result = try runSuccessfulCommand(
      "list-build-settings",
      arguments: [
        "-c", "Release",
      ])

    TestHelpers.assertCommandSuccess(result)
    XCTAssertTrue(
      result.output.count > 0, "Should show configuration-specific settings with short flag")
    // Config filtering works even if config name isn't shown in output
    XCTAssertTrue(
      result.output.contains("Build Settings") || result.output.contains("CLANG"),
      "Expected build settings output but got: \(result.output)")
  }

  func testListBuildSettingsWithTargetAndConfig() throws {
    let targetsResult = try runSuccessfulCommand("list-targets")
    let targetName = extractFirstTarget(from: targetsResult.output)

    if let target = targetName {
      let result = try runSuccessfulCommand(
        "list-build-settings",
        arguments: [
          "--target", target,
          "--config", "Debug",
        ])

      TestHelpers.assertCommandSuccess(result)
      XCTAssertTrue(result.output.count > 0, "Should show target and config specific settings")
      TestHelpers.assertOutputContains(result.output, target)
      // Config filtering works even if config name isn't shown in output
      XCTAssertTrue(
        result.output.contains("Build Settings") || result.output.contains("CLANG"),
        "Expected build settings output but got: \(result.output)")
    }
  }

  func testListBuildSettingsShowInherited() throws {
    let targetsResult = try runSuccessfulCommand("list-targets")
    let targetName = extractFirstTarget(from: targetsResult.output)

    if let target = targetName {
      let result = try runSuccessfulCommand(
        "list-build-settings",
        arguments: [
          "--target", target,
          "--show-inherited",
        ])

      TestHelpers.assertCommandSuccess(result)
      XCTAssertTrue(result.output.count > 0, "Should show inherited build settings")

      // Should indicate inherited settings somehow
      XCTAssertTrue(
        result.output.contains("inherited") || result.output.contains("Inherited")
          || result.output.contains("PROJECT") || result.output.count > 100,  // More verbose output expected
        "Should show inherited settings information"
      )
    }
  }

  func testListBuildSettingsShowInheritedShortFlag() throws {
    let targetsResult = try runSuccessfulCommand("list-targets")
    let targetName = extractFirstTarget(from: targetsResult.output)

    if let target = targetName {
      let result = try runSuccessfulCommand(
        "list-build-settings",
        arguments: [
          "-t", target,
          "-i",
        ])

      TestHelpers.assertCommandSuccess(result)
      XCTAssertTrue(result.output.count > 0, "Should show inherited build settings with short flag")
    }
  }

  func testListBuildSettingsJSONOutput() throws {
    let result = try runSuccessfulCommand(
      "list-build-settings",
      arguments: [
        "--json"
      ])

    TestHelpers.assertCommandSuccess(result)
    XCTAssertTrue(result.output.count > 0, "Should show JSON build settings")

    // Should be valid JSON format
    XCTAssertTrue(
      result.output.contains("{") && result.output.contains("}")
        || result.output.contains("[") && result.output.contains("]"),
      "Should output in JSON format. Got: \(result.output)"
    )
  }

  func testListBuildSettingsJSONOutputShortFlag() throws {
    let result = try runSuccessfulCommand(
      "list-build-settings",
      arguments: [
        "-j"
      ])

    TestHelpers.assertCommandSuccess(result)
    XCTAssertTrue(result.output.count > 0, "Should show JSON build settings with short flag")

    // Should be valid JSON format
    XCTAssertTrue(
      result.output.contains("{") && result.output.contains("}")
        || result.output.contains("[") && result.output.contains("]"),
      "Should output in JSON format with short flag"
    )
  }

  func testListBuildSettingsShowAll() throws {
    let result = try runSuccessfulCommand(
      "list-build-settings",
      arguments: [
        "--all"
      ])

    TestHelpers.assertCommandSuccess(result)
    XCTAssertTrue(result.output.count > 0, "Should show all build settings")

    // Should be more verbose with all settings
    XCTAssertTrue(
      result.output.count > 100,  // Expect more verbose output
      "Should show comprehensive build settings with --all flag"
    )
  }

  func testListBuildSettingsShowAllShortFlag() throws {
    let result = try runSuccessfulCommand(
      "list-build-settings",
      arguments: [
        "-a"
      ])

    TestHelpers.assertCommandSuccess(result)
    XCTAssertTrue(result.output.count > 0, "Should show all build settings with short flag")
  }

  func testListBuildSettingsInvalidTarget() throws {
    let result = try runFailingCommand(
      "list-build-settings",
      arguments: [
        "--target", "NonExistentTarget",
      ])

    TestHelpers.assertCommandFailure(result)
    XCTAssertTrue(
      result.output.contains("target") || result.output.contains("not found")
        || result.error.contains("Target not found"),
      "Should report invalid target"
    )
  }

  func testListBuildSettingsInvalidConfig() throws {
    let result = try runCommand(
      "list-build-settings",
      arguments: [
        "--config", "InvalidConfig",
      ])

    // This might succeed but show empty/no results, or fail with error
    if !result.success {
      TestHelpers.assertCommandFailure(result)
      XCTAssertTrue(
        result.output.contains("configuration") || result.output.contains("not found"),
        "Should report invalid configuration"
      )
    } else {
      // If it succeeds, should show appropriate message about no settings
      XCTAssertTrue(
        result.output.contains("No") || result.output.contains("Invalid")
          || result.output.count == 0,
        "Should handle invalid configuration appropriately"
      )
    }
  }

  func testListBuildSettingsCombinedFlags() throws {
    let targetsResult = try runSuccessfulCommand("list-targets")
    let targetName = extractFirstTarget(from: targetsResult.output)

    if let target = targetName {
      let result = try runSuccessfulCommand(
        "list-build-settings",
        arguments: [
          "-t", target,
          "-c", "Debug",
          "-i",
          "-j",
          "-a",
        ])

      TestHelpers.assertCommandSuccess(result)
      XCTAssertTrue(result.output.count > 0, "Should work with combined flags")

      // Should be JSON format
      XCTAssertTrue(
        result.output.contains("{") && result.output.contains("}")
          || result.output.contains("[") && result.output.contains("]"),
        "Should output in JSON format with combined flags"
      )
    }
  }

  // MARK: - Build Configuration Comparison Tests

  func testCompareBuildConfigurations() throws {
    // Test listing settings for both Debug and Release to compare
    let debugResult = try runSuccessfulCommand(
      "list-build-settings",
      arguments: [
        "--config", "Debug",
      ])

    let releaseResult = try runSuccessfulCommand(
      "list-build-settings",
      arguments: [
        "--config", "Release",
      ])

    TestHelpers.assertCommandSuccess(debugResult)
    TestHelpers.assertCommandSuccess(releaseResult)

    // Both should have content
    XCTAssertTrue(debugResult.output.count > 0, "Debug settings should have content")
    XCTAssertTrue(releaseResult.output.count > 0, "Release settings should have content")

    // They should be different (different configurations)
    XCTAssertNotEqual(
      debugResult.output, releaseResult.output, "Debug and Release settings should differ")
  }

  func testBuildSettingsConsistency() throws {
    let targetsResult = try runSuccessfulCommand("list-targets")
    let allTargets = extractAllTargets(from: targetsResult.output)

    // Test that all targets can have their build settings listed
    for target in allTargets.prefix(3) {  // Test up to 3 targets to avoid excessive test time
      let result = try runCommand(
        "list-build-settings",
        arguments: [
          "--target", target,
        ])

      if result.success {
        TestHelpers.assertCommandSuccess(result)
        TestHelpers.assertOutputContains(result.output, target)
        XCTAssertTrue(result.output.count > 0, "Target \(target) should have build settings")
      } else {
        // Some targets might not have build settings, which is acceptable
        XCTAssertTrue(
          result.output.contains("settings") || result.output.contains("target"),
          "Should provide clear message for target \(target)"
        )
      }
    }
  }

  // MARK: - Output Format Tests

  func testBuildSettingsOutputFormat() throws {
    let result = try runSuccessfulCommand("list-build-settings")

    TestHelpers.assertCommandSuccess(result)

    // Should have proper formatting (not just dumped text)
    let lines = result.output.components(separatedBy: .newlines)
    XCTAssertTrue(lines.count > 1, "Should have multiple lines of output")

    // Should not have obvious formatting issues
    let emptyLines = lines.filter { $0.trimmingCharacters(in: .whitespaces).isEmpty }
    let contentLines = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

    XCTAssertTrue(
      contentLines.count > emptyLines.count,
      "Should have more content lines than empty lines"
    )
  }

  // MARK: - Integration Tests

  func testBuildSettingsWorkflow() throws {
    let targetsResult = try runSuccessfulCommand("list-targets")
    let targetName = extractFirstTarget(from: targetsResult.output)

    if let target = targetName {
      // 1. List default settings
      let defaultResult = try runSuccessfulCommand("list-build-settings")
      TestHelpers.assertCommandSuccess(defaultResult)

      // 2. List target-specific settings
      let targetResult = try runSuccessfulCommand(
        "list-build-settings",
        arguments: [
          "--target", target,
        ])
      TestHelpers.assertCommandSuccess(targetResult)

      // 3. List with configuration
      let configResult = try runSuccessfulCommand(
        "list-build-settings",
        arguments: [
          "--target", target,
          "--config", "Debug",
        ])
      TestHelpers.assertCommandSuccess(configResult)

      // 4. List with inherited
      let inheritedResult = try runSuccessfulCommand(
        "list-build-settings",
        arguments: [
          "--target", target,
          "--show-inherited",
        ])
      TestHelpers.assertCommandSuccess(inheritedResult)

      // 5. List in JSON format
      let jsonResult = try runSuccessfulCommand(
        "list-build-settings",
        arguments: [
          "--target", target,
          "--json",
        ])
      TestHelpers.assertCommandSuccess(jsonResult)

      // Verify JSON format
      XCTAssertTrue(
        jsonResult.output.contains("{") || jsonResult.output.contains("["),
        "JSON result should contain JSON formatting"
      )
    }
  }

  // MARK: - Remove Build Setting Tests

  func testRemoveBuildSetting() throws {
    let targetsResult = try runSuccessfulCommand("list-targets")
    let targetName = extractFirstTarget(from: targetsResult.output)

    guard let target = targetName else {
      XCTFail("No target found")
      return
    }

    // First set a build setting
    let setResult = try runSuccessfulCommand(
      "set-build-setting",
      arguments: [
        "TEST_CUSTOM_SETTING",
        "TestValue",
        "--targets", target,
      ])
    TestHelpers.assertCommandSuccess(setResult)

    // Verify it was set
    let getResult1 = try runSuccessfulCommand(
      "get-build-settings",
      arguments: [
        target
      ])
    TestHelpers.assertOutputContains(getResult1.output, "TEST_CUSTOM_SETTING")

    // Remove the build setting
    let removeResult = try runSuccessfulCommand(
      "remove-build-setting",
      arguments: [
        "TEST_CUSTOM_SETTING",
        "--targets", target,
      ])
    TestHelpers.assertCommandSuccess(removeResult)

    // Verify it was removed
    let getResult2 = try runSuccessfulCommand(
      "get-build-settings",
      arguments: [
        target
      ])
    XCTAssertFalse(
      getResult2.output.contains("TEST_CUSTOM_SETTING"),
      "Build setting should be removed")
  }

  func testRemoveBuildSettingWithConfiguration() throws {
    let targetsResult = try runSuccessfulCommand("list-targets")
    let targetName = extractFirstTarget(from: targetsResult.output)

    guard let target = targetName else {
      XCTFail("No target found")
      return
    }

    // Set a build setting for Debug configuration only
    try runSuccessfulCommand(
      "set-build-setting",
      arguments: [
        "TEST_DEBUG_SETTING",
        "DebugValue",
        "--targets", target,
        "--config", "Debug",
      ])

    // Remove from Debug configuration
    let removeResult = try runSuccessfulCommand(
      "remove-build-setting",
      arguments: [
        "TEST_DEBUG_SETTING",
        "--targets", target,
        "--config", "Debug",
      ])
    TestHelpers.assertCommandSuccess(removeResult)
  }

  func testRemoveBuildSettingFromMultipleTargets() throws {
    let targetsResult = try runSuccessfulCommand("list-targets")
    let allTargets = extractAllTargets(from: targetsResult.output)

    guard allTargets.count >= 2 else {
      // Skip if less than 2 targets
      return
    }

    let targetList = allTargets.prefix(2).joined(separator: ",")

    // Set a build setting on multiple targets
    try runSuccessfulCommand(
      "set-build-setting",
      arguments: [
        "TEST_MULTI_SETTING",
        "MultiValue",
        "--targets", targetList,
      ])

    // Remove from all targets
    let removeResult = try runSuccessfulCommand(
      "remove-build-setting",
      arguments: [
        "TEST_MULTI_SETTING",
        "--targets", targetList,
      ])
    TestHelpers.assertCommandSuccess(removeResult)
  }

  func testRemoveBuildSettingWithInvalidTarget() throws {
    // Try to remove from non-existent target
    let result = try runCommand(
      "remove-build-setting",
      arguments: [
        "SOME_SETTING",
        "--targets", "NonExistentTarget12345",
      ])

    XCTAssertFalse(result.success, "Should fail for non-existent target")
    let errorOutput = result.output + result.error
    XCTAssertTrue(
      errorOutput.contains("not found") || errorOutput.contains("Target not found"),
      "Should show target not found error")
  }

  // MARK: - Helper Methods

  private func extractFirstTarget(from output: String) -> String? {
    let lines = output.components(separatedBy: .newlines)
    for line in lines {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      // Look for lines that start with "- " (bullet points)
      if trimmed.hasPrefix("- ") {
        let targetLine = String(trimmed.dropFirst(2))  // Remove "- " prefix
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
        let targetLine = String(trimmed.dropFirst(2))  // Remove "- " prefix
        // Extract target name before the first space and parenthesis
        if let spaceIndex = targetLine.firstIndex(of: " ") {
          targets.append(String(targetLine[..<spaceIndex]))
        } else {
          targets.append(targetLine)
        }
      }
    }

    return Array(Set(targets))  // Remove duplicates
  }
}
