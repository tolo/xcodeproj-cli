//
// StartupBenchmark.swift
// xcodeproj-cliTests
//
// Performance benchmarks for ArgumentParser migration (Phase 3)
//
// IMPORTANT: These tests establish baseline metrics for the post-Phase 2 implementation.
// After Phase 4 (legacy code removal), run these tests again and compare results.
//
// Current baseline metrics (Phase 2 complete):
// - Help generation: ~66ms (ArgumentParser overhead)
// - Command parsing: ~65ms (parsing and dispatch)
// - Memory peak: ~17-18MB (for typical operations)
//
// NOTE: Project operation tests (list-targets, validate) currently fail due to
// transaction system issues but still capture performance metrics successfully.
//

import Foundation
import XCTest

/// Performance benchmarks measuring startup time, help generation, and memory usage
/// These baselines are captured post-Phase 2 implementation and will be compared after Phase 4 (legacy code removal)
final class StartupBenchmark: XCTProjectTestCase {

  // MARK: - Help Generation Performance

  /// Measures the time to generate help text (ArgumentParser overhead)
  /// This captures the cost of ArgumentParser's reflection and help formatting
  func testHelpGenerationSpeed() throws {
    let metrics: [XCTMetric] = [
      XCTClockMetric()
    ]

    let options = XCTMeasureOptions()
    options.iterationCount = 10

    measure(metrics: metrics, options: options) {
      do {
        let process = Process()
        process.executableURL = TestHelpers.binaryPath
        process.arguments = ["--help"]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()
        process.waitUntilExit()

        // Verify help was generated
        XCTAssertEqual(process.terminationStatus, 0, "Help should succeed")

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""

        // Verify help contains expected content
        XCTAssertTrue(output.contains("USAGE"), "Help should contain usage information")

      } catch {
        XCTFail("Failed to measure help generation: \(error)")
      }
    }
  }

  /// Measures the time to generate subcommand help text
  /// This captures the cost of generating help for a specific command
  func testSubcommandHelpGenerationSpeed() throws {
    let metrics: [XCTMetric] = [
      XCTClockMetric()
    ]

    let options = XCTMeasureOptions()
    options.iterationCount = 10

    measure(metrics: metrics, options: options) {
      do {
        let process = Process()
        process.executableURL = TestHelpers.binaryPath
        process.arguments = ["add-file", "--help"]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()
        process.waitUntilExit()

        // Verify help was generated
        XCTAssertEqual(process.terminationStatus, 0, "Subcommand help should succeed")

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""

        // Verify help contains expected content
        XCTAssertTrue(output.contains("add-file"), "Help should contain command name")

      } catch {
        XCTFail("Failed to measure subcommand help generation: \(error)")
      }
    }
  }

  // MARK: - Command Parsing Performance

  /// Measures the time to parse and dispatch a command
  /// This captures ArgumentParser parsing overhead separate from execution
  func testCommandParsingSpeed() throws {
    let metrics: [XCTMetric] = [
      XCTClockMetric()
    ]

    let options = XCTMeasureOptions()
    options.iterationCount = 10

    measure(metrics: metrics, options: options) {
      do {
        let process = Process()
        process.executableURL = TestHelpers.binaryPath
        // Use a fast, read-only command to isolate parsing time
        process.arguments = ["list-targets", "--project", "NonExistent.xcodeproj"]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()
        process.waitUntilExit()

        // We expect this to fail (project doesn't exist)
        // but we've still measured the parsing overhead

      } catch {
        XCTFail("Failed to measure command parsing: \(error)")
      }
    }
  }

  // MARK: - Full Command Execution

  /// Measures end-to-end time for a complete read-only operation
  /// This establishes baseline for real-world command performance
  func testListTargetsPerformance() throws {
    let projectPath = TestHelpers.testProjectPath

    let metrics: [XCTMetric] = [
      XCTClockMetric(),
      XCTMemoryMetric(),
    ]

    let options = XCTMeasureOptions()
    options.iterationCount = 10

    measure(metrics: metrics, options: options) {
      do {
        let result = try TestHelpers.runCommand(
          "list-targets", arguments: ["--project", projectPath])
        XCTAssertTrue(result.success, "list-targets should succeed")

      } catch {
        XCTFail("Failed to measure list-targets performance: \(error)")
      }
    }
  }

  /// Measures end-to-end time for validation operation
  /// This establishes baseline for operations with transaction overhead
  func testValidationPerformance() throws {
    let projectPath = TestHelpers.testProjectPath

    let metrics: [XCTMetric] = [
      XCTClockMetric(),
      XCTMemoryMetric(),
    ]

    let options = XCTMeasureOptions()
    options.iterationCount = 5

    measure(metrics: metrics, options: options) {
      do {
        // Measure validate operation
        let result = try TestHelpers.runCommand(
          "validate",
          arguments: ["--project", projectPath]
        )
        XCTAssertTrue(result.success, "validate should succeed")

      } catch {
        XCTFail("Failed to measure validation performance: \(error)")
      }
    }
  }
}
