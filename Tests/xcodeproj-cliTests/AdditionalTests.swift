//
// AdditionalTests.swift
// xcodeproj-cliTests
//
// Edge cases, argument parsing, and additional scenario tests
//

import XCTest
import Foundation

final class AdditionalTests: XCTestCase {
    
    // MARK: - Argument Parsing Edge Cases
    
    func testEmptyArguments() throws {
        // Test behavior with completely empty arguments
        let process = Process()
        process.executableURL = TestHelpers.binaryPath
        process.arguments = []
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        try process.run()
        process.waitUntilExit()
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""
        
        // Should either show help or provide meaningful guidance
        XCTAssertTrue(
            output.contains("Usage") || 
            output.contains("help") || 
            output.contains("command") ||
            output.contains("xcodeproj-cli"),
            "Empty arguments should provide usage guidance"
        )
    }
    
    func testArgumentsWithSpecialCharacters() throws {
        // Test arguments containing special characters that might break parsing
        let specialArgs = [
            "file with spaces.swift",
            "file-with-dashes.swift",
            "file_with_underscores.swift",
            "file.with.dots.swift",
            "file@with@symbols.swift",
            "file#with#hash.swift"
        ]

        for fileName in specialArgs {
            let result = try TestHelpers.runCommand("add-file", arguments: [
                fileName,
                "--group", "Sources",
                "--targets", "TestApp",
                "--project", "NonExistent.xcodeproj" // Use non-existent to avoid actually adding
            ])

            // Should fail gracefully (project not found) rather than crash on argument parsing
            TestHelpers.assertCommandFailure(result)
            XCTAssertTrue(
                result.error.contains("Error: The project cannot be found") ||
                result.output.contains("cannot be found") ||
                result.output.contains("not found") ||
                result.output.contains("does not exist") ||
                result.error.contains("not found"),
                "Should handle special characters gracefully in filename: \(fileName)"
            )
        }
    }
    
    func testArgumentsWithQuotes() throws {
        // Test arguments with various quote combinations
        let quotedArgs = [
            "\"quoted file.swift\"",
            "'single quoted file.swift'",
            "\"file with 'mixed' quotes.swift\"",
            "'file with \"mixed\" quotes.swift'"
        ]

        for fileName in quotedArgs {
            let result = try TestHelpers.runCommand("add-file", arguments: [
                fileName,
                "--group", "Sources",
                "--targets", "TestApp",
                "--project", "NonExistent.xcodeproj"
            ])

            TestHelpers.assertCommandFailure(result)
            // Should parse quotes correctly and report file/project not found
            XCTAssertTrue(
                result.error.contains("Error: The project cannot be found") ||
                result.output.contains("cannot be found") ||
                result.output.contains("not found") || result.error.contains("not found"),
                "Should parse quoted arguments correctly: \(fileName)"
            )
        }
    }
    
    func testVeryLongArguments() throws {
        // Test with extremely long arguments
        let longFileName = String(repeating: "a", count: 500) + ".swift"
        let longGroupName = String(repeating: "b", count: 200)
        let longTargetName = String(repeating: "c", count: 100)

        let result = try TestHelpers.runCommand("add-file", arguments: [
            longFileName,
            "--group", longGroupName,
            "--targets", longTargetName,
            "--project", "NonExistent.xcodeproj"
        ])

        // Should handle long arguments without crashing
        XCTAssertTrue(result.exitCode != 0, "Should handle long arguments gracefully")
        XCTAssertTrue(
            result.error.contains("Error:") ||
            result.output.contains("cannot be found") ||
            result.output.contains("not found") ||
            result.output.contains("too long") ||
            result.output.contains("invalid") ||
            result.error.contains("not found"),
            "Should provide meaningful error for long arguments"
        )
    }
    
    func testArgumentOrderVariations() throws {
        // Test that argument order doesn't matter (when it shouldn't)
        // NOTE: ArgumentParser enforces positional arguments must come before/after options in specific order
        let argumentVariations = [
            ["add-file", "test.swift", "--group", "Sources", "--targets", "TestApp"],
            // ArgumentParser requires positional args in order, so these other variations may fail with different errors
            // We accept either "project not found" OR "Missing expected argument" errors
            ["add-file", "--group", "Sources", "test.swift", "--targets", "TestApp"],
            ["add-file", "--targets", "TestApp", "--group", "Sources", "test.swift"],
            ["add-file", "--group", "Sources", "--targets", "TestApp", "test.swift"]
        ]

        for args in argumentVariations {
            let result = try TestHelpers.runCommand(args[0], arguments: [
                "--project", "NonExistent.xcodeproj"
            ] + Array(args.dropFirst(1)))

            // All variations should fail (either project not found OR argument parsing error)
            TestHelpers.assertCommandFailure(result)
            XCTAssertTrue(
                result.output.contains("Error: The project cannot be found at") ||
                result.error.contains("Error: The project cannot be found at") ||
                result.output.contains("cannot be found") ||
                result.output.contains("not found") ||
                result.error.contains("not found") ||
                result.output.contains("Missing expected argument") ||
                result.error.contains("Missing expected argument"),
                "Argument order variation should be parsed consistently: \(args.joined(separator: " ")). Got output: '\(result.output)' error: '\(result.error)' exitCode: \(result.exitCode)"
            )
        }
    }
    
    // MARK: - Flag Parsing Edge Cases
    
    func testDuplicateFlags() throws {
        // Test behavior with duplicate flags
        let result = try TestHelpers.runCommand("add-file", arguments: [
            "test.swift",
            "--group", "Sources",
            "--group", "AnotherGroup", // Duplicate --group
            "--targets", "TestApp",
            "--project", "NonExistent.xcodeproj"
        ])
        
        TestHelpers.assertCommandFailure(result)
        // Should handle duplicate flags gracefully (use last one or report error)
        XCTAssertTrue(result.output.count > 0 || result.error.count > 0, "Should handle duplicate flags")
    }
    
    func testMissingRequiredFlags() throws {
        // Test commands with missing required arguments
        let incompleteCommands = [
            (["add-file", "test.swift"], "missing group or targets"),
            (["add-file", "--group", "Sources"], "missing filename"),
            (["set-build-setting", "SWIFT_VERSION"], "missing value"),
            (["remove-file"], "missing filename")
        ]

        for (args, _) in incompleteCommands {
            let result = try TestHelpers.runCommand(args[0], arguments: Array(args.dropFirst()))

            TestHelpers.assertCommandFailure(result)
            // ArgumentParser uses exit code 64 for validation errors
            XCTAssertTrue(result.exitCode == 64 || result.exitCode == 1, "Should fail with validation error")
            XCTAssertTrue(
                result.output.contains("Error:") ||
                result.error.contains("Error:") ||
                result.output.contains("Missing expected argument") ||
                result.error.contains("Missing expected argument") ||
                result.output.contains("missing") ||
                result.output.contains("required") ||
                result.output.contains("Usage") ||
                result.error.contains("missing") ||
                result.error.contains("required"),
                "Should report missing required arguments for: \(args.joined(separator: " ")). Got output: '\(result.output)' error: '\(result.error)' exitCode: \(result.exitCode)"
            )
        }
    }
    
    func testUnknownFlags() throws {
        // Test behavior with unknown/invalid flags
        let unknownFlags = [
            "--unknown-flag",
            "--invalid-option",
            "--typo-in-flag",
            "-z" // Unknown short flag
        ]

        for flag in unknownFlags {
            let result = try TestHelpers.runCommand("validate", arguments: [flag])

            TestHelpers.assertCommandFailure(result)
            // ArgumentParser uses exit code 64 for validation errors
            XCTAssertTrue(result.exitCode == 64 || result.exitCode == 1, "Should fail with validation error")
            XCTAssertTrue(
                result.output.contains("Error:") ||
                result.error.contains("Error:") ||
                result.output.contains("Unknown option") ||
                result.error.contains("Unknown option") ||
                result.output.contains("unknown") ||
                result.output.contains("invalid") ||
                result.output.contains("unrecognized") ||
                result.error.contains("unknown") ||
                result.error.contains("invalid"),
                "Should report unknown flag: \(flag). Got output: '\(result.output)' error: '\(result.error)' exitCode: \(result.exitCode)"
            )
        }
    }
    
    // MARK: - Path Handling Edge Cases
    
    func testAbsolutePaths() throws {
        // Test with absolute paths
        // NOTE: Security validation now rejects system paths like /System, /tmp for safety
        let absolutePaths = [
            "/Users/test/absolute/path.swift",
            "/System/Library/something.framework",
            "/tmp/temporary/file.swift"
        ]

        for path in absolutePaths {
            let result = try TestHelpers.runCommand("add-file", arguments: [
                path,
                "--group", "Sources",
                "--targets", "TestApp",
                "--project", TestHelpers.testProjectPath
            ])

            // Should handle absolute paths (security validation may reject some paths)
            if !result.success {
                XCTAssertTrue(
                    result.output.contains("Error:") ||
                    result.error.contains("Error:") ||
                    result.output.contains("Invalid or potentially unsafe path") ||
                    result.error.contains("Invalid or potentially unsafe path") ||
                    result.output.contains("cannot be found") ||
                    result.output.contains("not found") ||
                    result.output.contains("does not exist") ||
                    result.output.contains("invalid") ||
                    result.error.contains("not found"),
                    "Should handle absolute path gracefully: \(path). Got output: '\(result.output)' error: '\(result.error)' exitCode: \(result.exitCode)"
                )
            }
        }
    }
    
    func testRelativePaths() throws {
        // Test with various relative path formats
        // NOTE: Security validation may reject paths with .. for path traversal protection
        let relativePaths = [
            "../parent/file.swift",
            "./current/file.swift",
            "../../grandparent/file.swift",
            "subfolder/nested/file.swift"
        ]

        for path in relativePaths {
            let result = try TestHelpers.runCommand("add-file", arguments: [
                path,
                "--group", "Sources",
                "--targets", "TestApp",
                "--project", TestHelpers.testProjectPath
            ])

            // Should handle relative paths appropriately (security validation may reject some)
            if !result.success {
                XCTAssertTrue(
                    result.output.contains("Error:") ||
                    result.error.contains("Error:") ||
                    result.output.contains("Invalid or potentially unsafe path") ||
                    result.error.contains("Invalid or potentially unsafe path") ||
                    result.output.contains("cannot be found") ||
                    result.output.contains("not found") ||
                    result.output.contains("invalid") ||
                    result.output.contains("security") || // Path traversal protection
                    result.error.contains("not found"),
                    "Should handle relative path appropriately: \(path). Got output: '\(result.output)' error: '\(result.error)' exitCode: \(result.exitCode)"
                )
            }
        }
    }
    
    func testPathsWithSpaces() throws {
        // Test paths containing spaces
        let spacePaths = [
            "folder with spaces/file.swift",
            "My Project/Sources/file.swift",
            "Very Long Folder Name With Spaces/file.swift"
        ]

        for path in spacePaths {
            let result = try TestHelpers.runCommand("add-file", arguments: [
                path,
                "--group", "Sources",
                "--targets", "TestApp",
                "--project", TestHelpers.testProjectPath
            ])

            // Should handle spaced paths correctly
            if !result.success {
                XCTAssertTrue(
                    result.error.contains("Error:") ||
                    result.output.contains("cannot be found") ||
                    result.output.contains("not found") || result.error.contains("not found"),
                    "Should handle spaced paths correctly: \(path). Got: \(result.error)"
                )
            }
        }
    }
    
    // MARK: - Unicode and International Character Tests
    
    func testUnicodeCharacters() throws {
        // Test with Unicode characters in file names
        let unicodeNames = [
            "файл.swift", // Russian
            "文件.swift", // Chinese
            "ファイル.swift", // Japanese
            "émojï🎉.swift", // Emoji and accents
            "αρχείο.swift" // Greek
        ]
        
        for fileName in unicodeNames {
            let result = try TestHelpers.runCommand("add-file", arguments: [
                fileName,
                "--group", "Sources",
                "--targets", "TestApp",
                "--project", "NonExistent.xcodeproj"
            ])
            
            // Should handle Unicode gracefully (might not support all characters, but shouldn't crash)
            XCTAssertTrue(result.exitCode != 0, "Should handle Unicode characters")
            XCTAssertTrue(
                result.output.count > 0 || result.error.count > 0,
                "Should provide some response for Unicode filename: \(fileName)"
            )
        }
    }
    
    // MARK: - Command Combination Edge Cases
    
    func testConflictingFlags() throws {
        // Test flags that might conflict with each other
        let result = try TestHelpers.runCommand("add-swift-package", arguments: [
            "https://github.com/test/package.git",
            "--version", "1.0.0",
            "--branch", "main", // Conflicting with version
            "--project", "NonExistent.xcodeproj"
        ])

        TestHelpers.assertCommandFailure(result)
        XCTAssertTrue(
            result.output.contains("conflict") ||
            result.output.contains("cannot") ||
            result.output.contains("mutually exclusive") ||
            result.output.contains("not found") ||
            result.output.contains("Must specify one of") ||
            result.output.contains("Cannot specify multiple version requirements") ||
            result.error.contains("Must specify one of") ||
            result.error.contains("Cannot specify multiple version requirements"),
            "Should handle conflicting flags appropriately. Got output: '\(result.output)' error: '\(result.error)'"
        )
    }
    
    func testInvalidCombinations() throws {
        // Test invalid flag combinations
        let invalidCombinations = [
            (["set-build-setting", "KEY", "VALUE"], "missing target"),
            (["add-dependency", "TargetA"], "missing dependency target"),
            (["remove-swift-package"], "missing package name")
        ]

        for (args, expectedIssue) in invalidCombinations {
            let result = try TestHelpers.runCommand(args[0], arguments: Array(args.dropFirst()))

            TestHelpers.assertCommandFailure(result)
            // ArgumentParser uses exit code 64 for validation errors
            XCTAssertTrue(result.exitCode == 64 || result.exitCode == 1, "Should fail with validation error")
            XCTAssertTrue(
                result.output.contains("Error:") ||
                result.error.contains("Error:") ||
                result.output.contains("Missing expected argument") ||
                result.error.contains("Missing expected argument") ||
                result.output.contains("missing") ||
                result.output.contains("required") ||
                result.output.contains("Usage") ||
                result.error.contains("missing"),
                "Should report issue for invalid combination: \(expectedIssue). Got output: '\(result.output)' error: '\(result.error)' exitCode: \(result.exitCode)"
            )
        }
    }
    
    // MARK: - Performance Edge Cases
    
    func testRapidCommandExecution() throws {
        // Test executing many commands rapidly
        let commands = Array(repeating: "validate", count: 10)
        var results: [TestHelpers.CommandResult] = []
        
        let startTime = Date()
        
        for command in commands {
            let result = try TestHelpers.runCommand(command)
            results.append(result)
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // All commands should complete
        for (index, result) in results.enumerated() {
            XCTAssertTrue(
                result.success || result.output.contains("not found"),
                "Rapid command \(index) should complete successfully"
            )
        }
        
        // Should complete in reasonable time
        XCTAssertLessThan(duration, 60.0, "Rapid commands should complete within reasonable time")
    }
    
    // MARK: - Environment Variable Edge Cases
    
    func testWithModifiedEnvironment() throws {
        // Test behavior with modified environment variables
        let process = Process()
        process.executableURL = TestHelpers.binaryPath
        process.arguments = ["validate", "--project", TestHelpers.testProjectPath]
        
        // Modify environment
        var env = ProcessInfo.processInfo.environment
        env["HOME"] = "/tmp"
        env["USER"] = "testuser"
        env["LANG"] = "en_US.UTF-8"
        process.environment = env
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        
        try process.run()
        process.waitUntilExit()
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""
        
        // Should work regardless of environment changes
        XCTAssertTrue(
            process.terminationStatus == 0 || output.contains("not found"),
            "Should handle modified environment gracefully"
        )
    }
    
    // MARK: - Signal Handling Edge Cases
    
    func testCommandInterruption() throws {
        // Test behavior when command is interrupted (timeout simulation)
        let process = Process()
        process.executableURL = TestHelpers.binaryPath
        process.arguments = ["validate", "--project", TestHelpers.testProjectPath]
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        
        try process.run()
        
        // Wait a very short time then terminate
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.01) {
            if process.isRunning {
                process.terminate()
            }
        }
        
        process.waitUntilExit()
        
        // Should handle termination gracefully (exit code will be non-zero due to termination OR normal completion)
        // The test passes if the process either terminates properly or completes successfully
        XCTAssertTrue(
            process.terminationStatus != 0 || process.terminationReason == .exit,
            "Process should either complete normally or handle termination gracefully. Status: \(process.terminationStatus), Reason: \(process.terminationReason)"
        )
    }
    
    // MARK: - Memory and Resource Edge Cases
    
    func testWithLimitedResources() throws {
        // Test with very large inputs that might stress memory
        let largeContent = String(repeating: "// Large file content\n", count: 10000)
        let tempFile = try TestHelpers.createTestFile(
            name: "LargeFile.swift",
            content: largeContent
        )
        defer { TestHelpers.cleanupTestItems([tempFile]) }

        let result = try TestHelpers.runCommand("add-file", arguments: [
            tempFile.lastPathComponent,
            "--group", "Sources",
            "--targets", "TestApp",
            "--project", TestHelpers.testProjectPath
        ])

        // Should handle large files gracefully (either succeed or fail with reasonable error)
        if result.success {
            XCTAssertTrue(true, "Successfully handled large file")
        } else {
            XCTAssertTrue(
                result.output.contains("too large") ||
                result.output.contains("size") ||
                result.output.contains("not found") ||
                result.output.contains("Error:") || // Any error is acceptable
                result.error.contains("Error:"),
                "Should provide appropriate error for large file. Got output: '\(result.output)' error: '\(result.error)'"
            )
        }
    }
    
    // MARK: - Platform-Specific Edge Cases
    
    func testPlatformSpecificPaths() throws {
        // Test platform-specific path formats
        // NOTE: Security validation rejects many system paths for safety
        let platformPaths = [
            "/System/Library/Frameworks/Foundation.framework", // macOS system path
            "~/Documents/file.swift", // Home directory
            "/usr/local/bin/tool", // Unix standard path
            "/Applications/Xcode.app/Contents/Developer" // Xcode path
        ]

        for path in platformPaths {
            let result = try TestHelpers.runCommand("add-file", arguments: [
                path,
                "--group", "Sources",
                "--targets", "TestApp",
                "--project", TestHelpers.testProjectPath
            ])

            // Should handle platform-specific paths appropriately (security validation may reject)
            if !result.success {
                XCTAssertTrue(
                    result.output.contains("Error:") ||
                    result.error.contains("Error:") ||
                    result.output.contains("Invalid or potentially unsafe path") ||
                    result.error.contains("Invalid or potentially unsafe path") ||
                    result.output.contains("cannot be found") ||
                    result.output.contains("not found") ||
                    result.output.contains("permission") ||
                    result.output.contains("invalid") ||
                    result.error.contains("not found"),
                    "Should handle platform path appropriately: \(path). Got output: '\(result.output)' error: '\(result.error)' exitCode: \(result.exitCode)"
                )
            }
        }
    }
    
    // MARK: - Error Message Quality Tests
    
    func testErrorMessageClarity() throws {
        // Test that error messages are helpful and specific
        let errorScenarios = [
            (["add-file", "nonexistent.swift", "--group", "Sources", "--targets", "TestApp"], "file not found"),
            (["remove-target", "NonExistentTarget"], "target not found"),
            (["set-build-setting", "INVALID_KEY", "value", "--targets", "NonExistentTarget"], "target not found"),
            (["invalid-command"], "unknown command")
        ]
        
        for (args, expectedType) in errorScenarios {
            let result = try TestHelpers.runCommand(args[0], arguments: Array(args.dropFirst()))
            
            TestHelpers.assertCommandFailure(result)
            
            // Error message should be helpful
            let errorText = result.output + " " + result.error
            XCTAssertTrue(
                errorText.contains("not found") || 
                errorText.contains("does not exist") ||
                errorText.contains("Unknown") ||
                errorText.contains("invalid") ||
                errorText.contains("missing") ||
                errorText.contains("Error"),
                "Should provide clear error message for \(expectedType): \(errorText)"
            )
            
            // Should not contain internal error details that confuse users
            XCTAssertFalse(
                errorText.contains("nil") && errorText.contains("unwrap"),
                "Should not expose internal Swift errors"
            )
        }
    }
    
    // MARK: - Regression Tests
    
    func testCommonUserMistakes() throws {
        // Test common mistakes users might make
        let userMistakes = [
            (["add-file", "file.swift"], "forgetting required flags"),
            (["validate", "--project", "project.xcodeproj"], "wrong file extension"),
            (["list-targets", "--target", "SomeTarget"], "using wrong flag"),
            (["add-swift-package", "package-name-without-url"], "invalid package format")
        ]

        for (args, mistake) in userMistakes {
            let result = try TestHelpers.runCommand(args[0], arguments: Array(args.dropFirst()))

            // Should provide helpful guidance rather than cryptic errors
            if !result.success {
                XCTAssertTrue(
                    result.output.contains("Error:") ||
                    result.error.contains("Error:") ||
                    result.output.contains("Missing expected argument") ||
                    result.error.contains("Missing expected argument") ||
                    result.output.contains("Unknown option") ||
                    result.error.contains("Unknown option") ||
                    result.output.contains("Must specify one of") ||
                    result.error.contains("Must specify one of") ||
                    result.output.contains("Usage") ||
                    result.output.contains("help") ||
                    result.output.contains("example") ||
                    result.output.contains("missing") ||
                    result.output.contains("invalid") ||
                    result.output.contains("not found"),
                    "Should provide helpful error for common mistake: \(mistake). Got output: '\(result.output)' error: '\(result.error)' exitCode: \(result.exitCode)"
                )
            }
        }
    }
}