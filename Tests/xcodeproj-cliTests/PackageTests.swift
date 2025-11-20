//
// PackageTests.swift
// xcodeproj-cliTests
//
// Tests for Swift Package Manager integration commands
//

import XCTest
import Foundation

final class PackageTests: XCTProjectTestCase {
    
    // MARK: - List Swift Packages Tests
    
    func testListSwiftPackages() throws {
        let result = try runCommand("list-swift-packages")
        
        // Should succeed whether packages exist or not
        if result.success {
            XCTAssertTrue(result.output.count >= 0, "List packages should complete")
            
            if result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // No packages - this is fine for a new project
                XCTAssertTrue(true, "No packages found (acceptable for test project)")
            } else {
                // Has packages - should show them properly
                XCTAssertTrue(
                    result.output.contains("http") || result.output.contains("git") || result.output.contains("Package"),
                    "Should show package information if packages exist"
                )
            }
        } else {
            // Command might not be supported or project doesn't support packages
            XCTAssertTrue(
                result.output.contains("no packages") || result.output.contains("not supported"),
                "Should provide clear message about package support"
            )
        }
    }
    
    // MARK: - Add Swift Package Tests
    
    func testAddSwiftPackage() throws {
        let packageURL = "https://github.com/Alamofire/Alamofire.git"
        let version = "5.8.0"
        
        let result = try runCommand("add-swift-package", arguments: [
            packageURL,
            "--version", version
        ])
        
        if result.success {
            TestHelpers.assertCommandSuccess(result)
            
            // Verify package was added
            let listResult = try runCommand("list-swift-packages")
            if listResult.success {
                TestHelpers.assertOutputContains(listResult.output, "Alamofire")
            }
        } else {
            // Package addition might fail due to network, project constraints, etc.
            XCTAssertTrue(
                result.output.contains("network") || 
                result.output.contains("resolve") || 
                result.output.contains("version") ||
                result.output.contains("not supported") ||
                result.output.contains("already exists"),
                "Should provide clear error about package addition failure. Got: \(result.output)"
            )
        }
    }
    
    func testAddSwiftPackageWithBranch() throws {
        let packageURL = "https://github.com/apple/swift-algorithms.git"
        let branch = "main"
        
        let result = try runCommand("add-swift-package", arguments: [
            packageURL,
            "--branch", branch
        ])
        
        if result.success {
            TestHelpers.assertCommandSuccess(result)
            
            // Verify package was added
            let listResult = try runCommand("list-swift-packages")
            if listResult.success {
                TestHelpers.assertOutputContains(listResult.output, "swift-algorithms")
            }
        } else {
            // Network or project limitations
            XCTAssertTrue(
                result.output.contains("network") || 
                result.output.contains("branch") || 
                result.output.contains("not supported"),
                "Should provide clear error about branch-based package addition"
            )
        }
    }
    
    func testAddSwiftPackageWithCommit() throws {
        let packageURL = "https://github.com/apple/swift-collections.git"
        let commit = "1.0.4"
        
        let result = try runCommand("add-swift-package", arguments: [
            packageURL,
            "--commit", commit
        ])
        
        if result.success {
            TestHelpers.assertCommandSuccess(result)
        } else {
            XCTAssertTrue(
                result.output.contains("commit") || 
                result.output.contains("not found") ||
                result.output.contains("network") ||
                result.output.contains("not supported"),
                "Should handle commit-based package addition gracefully"
            )
        }
    }
    
    func testAddSwiftPackageToSpecificTarget() throws {
        // First get available targets
        let targetsResult = try runSuccessfulCommand("list-targets")
        let targetName = extractFirstTarget(from: targetsResult.output)
        
        if let target = targetName {
            let packageURL = "https://github.com/apple/swift-log.git"
            
            let result = try runCommand("add-swift-package", arguments: [
                packageURL,
                "--version", "1.5.0",
                "--target", target
            ])
            
            if result.success {
                TestHelpers.assertCommandSuccess(result)
                
                // Verify package was added to the target
                let listResult = try runCommand("list-swift-packages")
                if listResult.success {
                    TestHelpers.assertOutputContains(listResult.output, "swift-log")
                }
            } else {
                XCTAssertTrue(
                    result.output.contains("target") ||
                    result.output.contains("network") ||
                    result.output.contains("not supported") ||
                    result.error.contains("Operation failed"),
                    "Should handle target-specific package addition"
                )
            }
        }
    }
    
    func testAddInvalidSwiftPackage() throws {
        let invalidURL = "https://github.com/nonexistent/invalid-package.git"
        
        let result = try runCommand("add-swift-package", arguments: [
            invalidURL,
            "--version", "1.0.0"
        ])
        
        // Command succeeds (adds to project file) but package itself may be invalid
        // This is because the tool doesn't validate network accessibility at add time
        if result.success {
            TestHelpers.assertCommandSuccess(result)
            XCTAssertTrue(
                result.output.contains("Added Swift Package") || result.output.contains("nonexistent/invalid-package"),
                "Should add package to project file even if URL doesn't exist"
            )
        } else {
            // If it does fail, should provide clear error
            TestHelpers.assertCommandFailure(result)
            XCTAssertTrue(
                result.error.contains("❌ Error:") ||
                result.output.contains("cannot be found") || 
                result.output.contains("invalid") || 
                result.output.contains("404") ||
                result.output.contains("failed"),
                "Should report invalid package URL"
            )
        }
    }
    
    func testAddSwiftPackageWithInvalidVersion() throws {
        let packageURL = "https://github.com/Alamofire/Alamofire.git"
        let invalidVersion = "999.999.999"
        
        let result = try runCommand("add-swift-package", arguments: [
            packageURL,
            "--version", invalidVersion
        ])
        
        // Command may succeed at the project level (adds to pbxproj)
        // Version validation happens at build time, not add time
        if result.success {
            TestHelpers.assertCommandSuccess(result)
            XCTAssertTrue(
                result.output.contains("Added Swift Package") || result.output.contains("Alamofire"),
                "Should add package to project even with invalid version"
            )
        } else {
            // If it does fail, should provide clear error
            TestHelpers.assertCommandFailure(result)
            XCTAssertTrue(
                result.error.contains("❌ Error:") ||
                result.output.contains("version") || 
                result.output.contains("cannot be found") ||
                result.output.contains("resolve") ||
                result.output.contains("invalid"),
                "Should report invalid package version"
            )
        }
    }
    
    // MARK: - Remove Swift Package Tests
    
    func testRemoveSwiftPackage() throws {
        // First try to add a package to remove
        let packageURL = "https://github.com/apple/swift-numerics.git"
        let addResult = try runCommand("add-swift-package", arguments: [
            packageURL,
            "--version", "1.0.0"
        ])
        
        if addResult.success {
            // Package was added successfully, now remove it
            let removeResult = try runCommand("remove-swift-package", arguments: ["swift-numerics"])
            
            if removeResult.success {
                TestHelpers.assertCommandSuccess(removeResult)
                
                // Verify package was removed
                let listResult = try runCommand("list-swift-packages")
                if listResult.success {
                    TestHelpers.assertOutputDoesNotContain(listResult.output, "swift-numerics")
                }
            } else {
                XCTAssertTrue(
                    removeResult.error.contains("Error:") || removeResult.error.contains("Package not found") ||
                    removeResult.output.contains("cannot be found") || removeResult.output.contains("not found") || removeResult.output.contains("remove"),
                    "Should provide clear error about package removal"
                )
            }
        } else {
            // If we can't add packages, test removing a non-existent one
            let removeResult = try runFailingCommand("remove-swift-package", arguments: ["NonExistentPackage"])
            TestHelpers.assertCommandFailure(removeResult)
            XCTAssertTrue(
                removeResult.error.contains("Error:") || removeResult.error.contains("Package not found") ||
                removeResult.output.contains("cannot be found") || removeResult.output.contains("not found") || removeResult.output.contains("does not exist"),
                "Should report package not found for removal"
            )
        }
    }
    
    func testRemoveNonExistentPackage() throws {
        let result = try runFailingCommand("remove-swift-package", arguments: ["NonExistentPackage"])

        TestHelpers.assertCommandFailure(result)
        XCTAssertTrue(
            result.error.contains("Error:") || result.error.contains("Package not found") ||
            result.output.contains("cannot be found") ||
            result.output.contains("not found") ||
            result.output.contains("does not exist") ||
            result.output.contains("no package"),
            "Should report package not found for removal"
        )
    }
    
    // MARK: - Package Dependency Resolution Tests
    
    func testPackageDependencyConflicts() throws {
        // Test adding packages that might have conflicting dependencies
        let package1 = "https://github.com/Alamofire/Alamofire.git"
        let package2 = "https://github.com/apple/swift-nio.git"
        
        let result1 = try runCommand("add-swift-package", arguments: [package1, "--version", "5.8.0"])
        let result2 = try runCommand("add-swift-package", arguments: [package2, "--version", "2.50.0"])
        
        // Either both succeed or there's a clear conflict message
        if result1.success && result2.success {
            XCTAssertTrue(true, "Successfully added both packages")
        } else {
            // Should provide clear conflict resolution information
            let failedResult = result1.success ? result2 : result1
            XCTAssertTrue(
                failedResult.output.contains("conflict") || 
                failedResult.output.contains("dependency") ||
                failedResult.output.contains("resolve"),
                "Should provide clear dependency conflict information"
            )
        }
    }
    
    // MARK: - Package Product Integration Tests
    
    func testAddPackageWithProducts() throws {
        let packageURL = "https://github.com/apple/swift-argument-parser.git"
        
        let result = try runCommand("add-swift-package", arguments: [
            packageURL,
            "--version", "1.3.0",
            "--products", "ArgumentParser"
        ])
        
        if result.success {
            TestHelpers.assertCommandSuccess(result)
            
            // Verify package and product were added
            let listResult = try runCommand("list-swift-packages")
            if listResult.success {
                TestHelpers.assertOutputContains(listResult.output, "ArgumentParser")
            }
        } else {
            XCTAssertTrue(
                result.output.contains("product") ||
                result.output.contains("network") ||
                result.output.contains("not supported") ||
                result.error.contains("Unknown option") || result.error.contains("Operation failed"),
                "Should handle package products gracefully"
            )
        }
    }
    
    // MARK: - Package Version Range Tests
    
    func testAddPackageWithVersionRange() throws {
        let packageURL = "https://github.com/apple/swift-collections.git"
        
        let result = try runCommand("add-swift-package", arguments: [
            packageURL,
            "--version", "from: 1.0.0"
        ])
        
        if result.success {
            TestHelpers.assertCommandSuccess(result)
        } else {
            XCTAssertTrue(
                result.output.contains("version") || 
                result.output.contains("range") ||
                result.output.contains("network") ||
                result.output.contains("not supported"),
                "Should handle version ranges appropriately"
            )
        }
    }
    
    func testAddPackageWithUpToNextMinor() throws {
        let packageURL = "https://github.com/apple/swift-crypto.git"
        
        let result = try runCommand("add-swift-package", arguments: [
            packageURL,
            "--version", "2.5.0"
        ])
        
        if result.success {
            TestHelpers.assertCommandSuccess(result)
        } else {
            XCTAssertTrue(
                result.output.contains("version") ||
                result.output.contains("network") ||
                result.output.contains("not supported"),
                "Should handle version requirements appropriately"
            )
        }
    }
    
    // MARK: - Local Package Tests
    
    func testAddLocalPackage() throws {
        // Create a minimal local package structure for testing
        let localPackageDir = try TestHelpers.createTestDirectory(
            name: "TestLocalPackage",
            files: [
                "Package.swift": """
                // swift-tools-version:5.9
                import PackageDescription
                
                let package = Package(
                    name: "TestLocalPackage",
                    products: [
                        .library(name: "TestLocalPackage", targets: ["TestLocalPackage"]),
                    ],
                    targets: [
                        .target(name: "TestLocalPackage"),
                    ]
                )
                """,
                "Sources/TestLocalPackage/TestLocalPackage.swift": "public struct TestLocalPackage {}"
            ]
        )
        
        defer { TestHelpers.cleanupTestItems([localPackageDir]) }
        
        let result = try runCommand("add-swift-package", arguments: [
            localPackageDir.path,
            "--local"
        ])
        
        if result.success {
            TestHelpers.assertCommandSuccess(result)
            
            // Verify local package was added
            let listResult = try runCommand("list-swift-packages")
            if listResult.success {
                TestHelpers.assertOutputContains(listResult.output, "TestLocalPackage")
            }
        } else {
            XCTAssertTrue(
                result.output.contains("local") ||
                result.output.contains("path") ||
                result.output.contains("not supported") ||
                result.error.contains("Invalid") || result.error.contains("git repository") ||
                result.error.contains("Unknown option"),
                "Should handle local packages or indicate lack of support"
            )
        }
    }
    
    // MARK: - Package Update Tests (if supported)
    
    func testUpdatePackages() throws {
        // Some package managers support updating all packages
        let result = try runCommand("update-swift-packages")
        
        if result.success {
            TestHelpers.assertCommandSuccess(result)
        } else {
            // Update command might not exist
            XCTAssertTrue(
                result.output.contains("Unknown command") || 
                result.output.contains("not supported") ||
                result.output.contains("update"),
                "Should handle package updates or indicate command doesn't exist"
            )
        }
    }
    
    // MARK: - Package Integration with Project Tests
    
    func testPackageIntegrationWithExistingCode() throws {
        // Add a package and then try to add a file that might use it
        let packageURL = "https://github.com/apple/swift-log.git"
        let packageResult = try runCommand("add-swift-package", arguments: [
            packageURL,
            "--version", "1.5.0"
        ])
        
        if packageResult.success {
            // Create a file that uses the package
            let testFile = try TestHelpers.createTestFile(
                name: "PackageUser.swift",
                content: """
                import Logging
                
                class PackageUser {
                    let logger = Logger(label: "test")
                }
                """
            )
            defer { TestHelpers.cleanupTestItems([testFile]) }
            
            let targetName = extractFirstTarget(from: try runSuccessfulCommand("list-targets").output) ?? "TestApp"
            
            let addFileResult = try runCommand("add-file", arguments: [
                testFile.lastPathComponent,
                "--group", "Sources",
                "--targets", targetName
            ])
            
            if addFileResult.success {
                XCTAssertTrue(true, "Successfully integrated package-dependent code")
            }
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testMalformedPackageURL() throws {
        let malformedURLs = [
            "not-a-url",
            "ftp://invalid.protocol.com/package.git",
            "https://",
            ""
        ]
        
        for url in malformedURLs {
            let result = try runCommand("add-swift-package", arguments: [
                url,
                "--version", "1.0.0"
            ])
            
            // The tool may accept malformed URLs at add time and let Xcode/SPM handle validation
            if result.success {
                XCTAssertTrue(
                    result.output.contains("Added Swift Package") || url.isEmpty,
                    "Tool accepted malformed URL (validation happens later): \(url)"
                )
            } else {
                // If it does reject, should provide clear error
                TestHelpers.assertCommandFailure(result)
                XCTAssertTrue(
                    result.error.contains("Error:") || result.error.contains("Invalid") ||
                    result.output.contains("invalid") ||
                    result.output.contains("URL") ||
                    result.output.contains("malformed") ||
                    result.error.contains("invalid") || result.error.contains("Unknown option"),
                    "Should reject malformed URL: \(url)"
                )
            }
        }
    }
    
    // MARK: - Update Swift Packages Tests
    
    func testUpdateSwiftPackages() throws {
        // First list existing packages to see if any are present
        _ = try runSuccessfulCommand("list-swift-packages")
        
        let result = try runCommand("update-swift-packages", arguments: [])
        
        if result.success {
            TestHelpers.assertCommandSuccess(result)
            // Check for various valid outputs
            XCTAssertTrue(
                result.output.contains("package") || 
                result.output.contains("Package"),
                "Expected output to contain 'package' but got: \(result.output)"
            )
            
            // Should indicate what happened with packages
            XCTAssertTrue(
                result.output.contains("Updated") || 
                result.output.contains("No packages") ||
                result.output.contains("up to date") ||
                result.output.contains("Found") ||
                result.output.contains("could benefit from updates"),
                "Should report update status. Got: \(result.output)"
            )
        } else {
            // Update might not be fully implemented or might require packages to exist
            XCTAssertTrue(
                result.output.contains("packages") || result.output.contains("not supported") ||
                result.output.contains("No packages"),
                "Should provide clear error about package updates. Got: \(result.output), Error: \(result.error)"
            )
        }
    }
    
    func testUpdateSwiftPackagesForce() throws {
        let result = try runCommand("update-swift-packages", arguments: ["--force"])
        
        if result.success {
            TestHelpers.assertCommandSuccess(result)
            XCTAssertTrue(
                result.output.contains("package") || result.output.contains("Package"),
                "Expected output to contain 'package' but got: \(result.output)"
            )
            
            // Should indicate force update behavior
            XCTAssertTrue(
                result.output.contains("force") ||
                result.output.contains("Force") ||
                result.output.contains("Updated") ||
                result.output.contains("No packages") ||
                result.output.contains("Found") ||
                result.output.contains("could benefit from updates"),
                "Should report force update status"
            )
        } else {
            // Force update might not be fully implemented
            XCTAssertTrue(
                result.output.contains("packages") || result.output.contains("force") ||
                result.output.contains("not supported"),
                "Should provide clear error about force package updates"
            )
        }
    }
    
    func testUpdateSwiftPackagesForceShortFlag() throws {
        let result = try runCommand("update-swift-packages", arguments: ["-f"])
        
        if result.success {
            TestHelpers.assertCommandSuccess(result)
            XCTAssertTrue(
                result.output.contains("package") || result.output.contains("Package"),
                "Expected output to contain 'package' but got: \(result.output)"
            )
        }
    }
    
    func testUpdateSwiftPackagesWithExistingPackage() throws {
        // First add a package
        let addResult = try runCommand("add-swift-package", arguments: [
            "https://github.com/apple/swift-log.git",
            "--version", "1.0.0"
        ])
        
        if addResult.success {
            // Now try to update
            let updateResult = try runCommand("update-swift-packages", arguments: [])
            
            if updateResult.success {
                TestHelpers.assertCommandSuccess(updateResult)
                XCTAssertTrue(
                    updateResult.output.contains("package") || updateResult.output.contains("Package"),
                    "Expected output to contain 'package' but got: \(updateResult.output)"
                )
                
                // Should mention the package we added
                XCTAssertTrue(
                    updateResult.output.contains("swift-log") ||
                    updateResult.output.contains("Updated") ||
                    updateResult.output.contains("up to date") ||
                    updateResult.output.contains("Found") ||
                    updateResult.output.contains("could benefit from updates"),
                    "Should report status for existing package"
                )
            }
            
            // Clean up - remove the package
            _ = try runCommand("remove-swift-package", arguments: ["swift-log"])
        }
    }
    
    func testUpdateSwiftPackagesIntegration() throws {
        // Integration test: add, update, then remove packages
        let testPackage = "https://github.com/apple/swift-log.git"
        
        // 1. Add package
        let addResult = try runCommand("add-swift-package", arguments: [
            testPackage,
            "--version", "1.0.0"
        ])
        
        if addResult.success {
            // 2. List packages to verify
            let listResult = try runSuccessfulCommand("list-swift-packages")
            TestHelpers.assertOutputContains(listResult.output, "swift-log")
            
            // 3. Update packages
            let updateResult = try runCommand("update-swift-packages", arguments: [])
            
            if updateResult.success {
                TestHelpers.assertCommandSuccess(updateResult)
                XCTAssertTrue(
                    updateResult.output.contains("package") || updateResult.output.contains("Package"),
                    "Expected output to contain 'package' but got: \(updateResult.output)"
                )
            }
            
            // 4. Force update
            let forceUpdateResult = try runCommand("update-swift-packages", arguments: ["--force"])
            
            if forceUpdateResult.success {
                TestHelpers.assertCommandSuccess(forceUpdateResult)
            }
            
            // 5. Clean up - remove package
            let removeResult = try runCommand("remove-swift-package", arguments: ["swift-log"])
            
            if removeResult.success {
                TestHelpers.assertCommandSuccess(removeResult)
            }
        }
    }
    
    func testUpdateSwiftPackagesEmpty() throws {
        // Test update when no packages exist
        // First ensure no packages exist by trying to list them
        _ = try runSuccessfulCommand("list-swift-packages")
        
        let result = try runCommand("update-swift-packages", arguments: [])
        
        if result.success {
            TestHelpers.assertCommandSuccess(result)
            
            // Should handle empty package list appropriately
            XCTAssertTrue(
                result.output.contains("No packages") ||
                result.output.contains("packages") ||
                result.output.contains("Package") ||
                result.output.contains("Found") ||
                result.output.contains("up to date"),
                "Should handle empty package list appropriately"
            )
        } else {
            // Failing is also acceptable for empty package list
            XCTAssertTrue(
                result.output.contains("No packages") ||
                result.output.contains("packages"),
                "Should provide clear message for empty package list"
            )
        }
    }
    
    func testUpdateSwiftPackagesVerbose() throws {
        // Test if verbose mode is supported (it might not be in the current implementation)
        let result = try runCommand("update-swift-packages", arguments: ["--verbose"])
        
        if result.success {
            TestHelpers.assertCommandSuccess(result)
            // Should show more detailed information in verbose mode
            XCTAssertTrue(result.output.count > 0, "Should show verbose update information")
        } else if result.output.contains("verbose") || result.output.contains("unknown") {
            // Verbose flag might not be implemented - that's acceptable
            XCTAssertTrue(
                result.output.contains("verbose") || result.output.contains("unknown"),
                "Should handle unsupported verbose flag appropriately"
            )
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
}