//
// SecurityPathTraversalTests.swift
// xcodeproj-cli
//
// Tests for path traversal security fixes

import XCTest

@testable import xcodeproj_cli

final class SecurityPathTraversalTests: XCTestCase {

  func testValidParentDirectoryAccess() {
    // Test that legitimate parent directory access is allowed
    let validPaths = [
      "../SomeFolder/file.swift",
      "../Shared/Utils.swift",
      "Folder/../OtherFolder/file.swift",
    ]

    for path in validPaths {
      let result = SecurityUtils.sanitizePath(path)
      XCTAssertNotNil(result, "Valid path '\(path)' should be allowed")
    }
  }

  func testInvalidRootEscape() {
    // Test that paths escaping root boundary are rejected
    let rootPath = "/Users/test/project"
    let invalidPaths = [
      "../../outside/file.swift",
      "../../../etc/passwd",
      "../../../../tmp/malicious.sh",
    ]

    for path in invalidPaths {
      let result = SecurityUtils.sanitizePath(path, rootPath: rootPath)
      XCTAssertNil(result, "Path '\(path)' should be rejected as it escapes root")
    }
  }

  func testAbsolutePathWithinRoot() {
    // Test that absolute paths within root are allowed
    let rootPath = "/Users/test/project"
    let validAbsolutePaths = [
      "/Users/test/project/Sources/File.swift",
      "/Users/test/project/Subfolder/Other.swift",
    ]

    for path in validAbsolutePaths {
      let result = SecurityUtils.sanitizePath(path, rootPath: rootPath)
      XCTAssertNotNil(result, "Absolute path '\(path)' within root should be allowed")
    }
  }

  func testAbsolutePathOutsideRoot() {
    // Test that absolute paths outside root are rejected when root is specified
    let rootPath = "/Users/test/project"
    let invalidAbsolutePaths = [
      "/Users/other/project/file.swift",
      "/tmp/evil.sh",
      "/etc/passwd",
    ]

    for path in invalidAbsolutePaths {
      let result = SecurityUtils.sanitizePath(path, rootPath: rootPath)
      XCTAssertNil(result, "Absolute path '\(path)' outside root should be rejected")
    }
  }

  func testSymlinkAttacks() {
    // Test that encoded traversal attempts are blocked
    let suspiciousPaths = [
      "%2e%2e/file.swift",
      "..%2ffile.swift",
      "folder/..%5c..%5cfile.swift",
    ]

    for path in suspiciousPaths {
      let result = SecurityUtils.sanitizePath(path)
      XCTAssertNil(result, "Suspicious path '\(path)' should be rejected")
    }
  }

  func testNullByteAttack() {
    // Test that null bytes are rejected
    let pathWithNull = "file.swift\0malicious"
    let result = SecurityUtils.sanitizePath(pathWithNull)
    XCTAssertNil(result, "Path with null byte should be rejected")
  }

  func testControlCharacters() {
    // Test that control characters are rejected
    let pathsWithControl = [
      "file\nname.swift",
      "file\rname.swift",
      "file\tname.swift",
    ]

    for path in pathsWithControl {
      let result = SecurityUtils.sanitizePath(path)
      XCTAssertNil(result, "Path '\(path)' with control characters should be rejected")
    }
  }

  func testDoubleDotInFilename() {
    // Test that ".." in filename (not as path component) is handled correctly
    let filename = "file..backup.swift"
    let result = SecurityUtils.sanitizePath(filename)
    XCTAssertNotNil(result, "Filename with '..' should be allowed")
  }

  func testRelativePathWithoutRoot() {
    // Test depth-based check when no root is specified
    let validPaths = [
      "Sources/File.swift",
      "./Sources/File.swift",
      "Folder/Subfolder/File.swift",
    ]

    for path in validPaths {
      let result = SecurityUtils.sanitizePath(path)
      XCTAssertNotNil(result, "Valid relative path '\(path)' should be allowed")
    }
  }

  func testNegativeDepthWithoutRoot() {
    // Test that paths with .. are allowed without root context
    // (as they're legitimate for parent directory access in Xcode projects)
    let result = SecurityUtils.sanitizePath("../../../file.swift")
    XCTAssertNotNil(
      result, "Path with .. should be allowed without root context (for legitimate parent access)")
  }
}
