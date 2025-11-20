//
// SecurityUtils.swift
// xcodeproj-cli
//
// Security and shell command utilities
//

import Foundation

/// Security utilities for safe shell command execution
struct SecurityUtils {

  /// Escape shell command to prevent injection attacks
  static func escapeShellCommand(_ command: String) -> String {
    // Use single quotes to prevent shell expansion and escape embedded single quotes
    // This handles the tricky case of embedded single quotes in shell commands
    let escaped = command.replacingOccurrences(of: "'", with: "'\"'\"'")
    return "'\(escaped)'"
  }

  /// Validate shell script for dangerous patterns while allowing legitimate scripting features
  /// This function blocks high-risk code injection patterns while permitting standard shell features
  /// needed for real Xcode build scripts (multi-line scripts, pipes, redirects, etc.)
  static func validateShellScript(_ script: String) -> Bool {
    // Block high-risk patterns that enable code injection or execution
    let dangerousPatterns = [
      "$(",  // Command substitution - allows arbitrary code execution
      "`",  // Command substitution (backticks) - same risk
      "eval ",  // Direct code evaluation - extremely dangerous
      "exec ",  // Process replacement - can hijack execution
      " | sh",  // Piping to shell interpreter - code injection vector
      " | bash",  // Piping to bash - code injection vector
      " | zsh",  // Piping to zsh - code injection vector
      "../",  // Path traversal in commands - security risk
    ]

    // Note: We intentionally ALLOW the following patterns which are legitimate for build scripts:
    // - Newlines (\n) - Multi-line scripts are standard in Xcode build phases
    // - Semicolons (;) - Command sequences are common and safe
    // - Pipes (|) - Tool chaining (e.g., swiftlint | xcpretty) is legitimate
    // - Redirects (>, >>, <) - File I/O is standard in build scripts
    // - Command chaining (&&, ||) - Conditional execution is safe
    // - Home directory (~) - Safe when not in command substitution context
    // - Variable expansion (${VAR}) - Xcode build settings require this

    let scriptLower = script.lowercased()
    for pattern in dangerousPatterns {
      if scriptLower.contains(pattern.lowercased()) {
        return false
      }
    }

    return true
  }

  /// Safe shell script sanitization - reject rather than filter for security
  static func safeShellScript(_ script: String) -> String? {
    guard validateShellScript(script) else {
      return nil  // Reject dangerous scripts entirely
    }
    return script  // Return original if safe
  }

  /// Validate build settings to prevent dangerous injections
  static func validateBuildSetting(key: String, value: String) -> Bool {
    // Dangerous build settings that could lead to code execution
    let dangerousSettings = [
      "OTHER_LDFLAGS",
      "OTHER_SWIFT_FLAGS",
      "OTHER_CFLAGS",
      "OTHER_CPLUSPLUSFLAGS",
      "LD_RUNPATH_SEARCH_PATHS",
      "FRAMEWORK_SEARCH_PATHS",
      "LIBRARY_SEARCH_PATHS",
      "HEADER_SEARCH_PATHS",
      "GCC_PREPROCESSOR_DEFINITIONS",
      "SWIFT_ACTIVE_COMPILATION_CONDITIONS",
      "RUN_CLANG_STATIC_ANALYZER",
      "PREBINDING",
    ]

    // Check if this is a dangerous setting that needs validation
    if dangerousSettings.contains(key) {
      // Look for suspicious patterns that could indicate code injection
      let suspiciousPatterns = [
        "$(",  // Command substitution
        "`",  // Command substitution (backticks)
        "${",  // Variable expansion
        ";",  // Command separator
        "&&",  // Command chaining
        "||",  // Command chaining OR
        "|",  // Pipe
        ">",  // File redirection
        "<",  // File input redirection
        "eval ",  // Code evaluation
        "exec ",  // Process execution
        "\n",  // Newlines for injection
        "\r",  // Carriage returns
        "../",  // Path traversal attempts
        "~",  // Home directory expansion
      ]

      let valueLower = value.lowercased()
      for pattern in suspiciousPatterns {
        if valueLower.contains(pattern.lowercased()) {
          return false  // Reject suspicious values
        }
      }

      // Additional validation for specific dangerous settings
      if key == "OTHER_LDFLAGS" {
        // Check for dangerous linker flags
        let dangerousLdFlags = [
          "-execute",  // Allow execution
          "-dylib_file",  // Dynamic library file substitution
          "-reexport",  // Re-export symbols
        ]

        for flag in dangerousLdFlags {
          if valueLower.contains(flag) {
            return false
          }
        }
      }
    }

    // Validate paths in path-related settings don't allow traversal
    let pathSettings = ["FRAMEWORK_SEARCH_PATHS", "LIBRARY_SEARCH_PATHS", "HEADER_SEARCH_PATHS"]
    if pathSettings.contains(key) {
      // Use our existing path validation for path-based settings
      let pathComponents = value.components(separatedBy: " ")
      for component in pathComponents {
        if !component.isEmpty && sanitizePath(component) == nil {
          return false
        }
      }
    }

    return true
  }

  /// Sanitize and validate a user-provided path for security
  /// - Parameters:
  ///   - path: The path to validate
  ///   - rootPath: Optional root boundary path (if provided, prevents escaping this root)
  /// - Returns: The sanitized path if valid, nil otherwise
  static func sanitizePath(_ path: String, rootPath: String? = nil) -> String? {
    // Limit path length to prevent resource exhaustion
    guard path.count <= 1024 else {
      return nil  // Path too long
    }

    // Check for null bytes
    if path.contains("\0") {
      return nil
    }

    // Check for encoded traversal attempts BEFORE decoding
    let pathLower = path.lowercased()
    let encodedTraversalPatterns = ["%2e%2e", "%2f", "%5c"]
    for pattern in encodedTraversalPatterns {
      if pathLower.contains(pattern) {
        return nil  // Reject encoded traversal attempts
      }
    }

    // Decode URL-encoded sequences that could be used to bypass filters
    guard let decodedPath = path.removingPercentEncoding else {
      return nil
    }

    // Normalize path by resolving . and .. components
    let normalizedPath = (decodedPath as NSString).standardizingPath

    // If rootPath is provided, validate against root boundary
    if let rootPath = rootPath {
      // Resolve absolute paths for proper boundary checking
      let resolvedRoot = (rootPath as NSString).standardizingPath

      // For relative paths, resolve relative to root
      let resolvedPath: String
      if normalizedPath.hasPrefix("/") {
        resolvedPath = normalizedPath
      } else {
        // Combine root with relative path and standardize
        let combined =
          ((resolvedRoot as NSString).appendingPathComponent(normalizedPath) as NSString)
          .standardizingPath
        resolvedPath = combined
      }

      // Check if resolved path is within root boundary
      // Path must start with root path and be separated by / or be exactly equal
      if resolvedPath == resolvedRoot {
        // Exact match is fine
      } else if resolvedPath.hasPrefix(resolvedRoot + "/") {
        // Within root boundary
      } else {
        // Path escapes root boundary
        return nil
      }
    }
    // Note: When no rootPath is provided, we allow paths starting with ".."
    // This is intentional to support legitimate parent directory references
    // like "../SomeFolder/file.swift" which are valid in Xcode projects

    // Note: We intentionally DO NOT block absolute paths to system directories
    // (e.g., /tmp/, /System/Library/Frameworks/) because:
    // 1. The CLI only adds REFERENCES to files in the .xcodeproj structure, it doesn't write to those locations
    // 2. Legitimate use cases include: temporary generated files (/tmp/), system frameworks (/System/Library/), etc.
    // 3. The boundary check above (when rootPath is provided) prevents escaping the project root
    // 4. Actual file I/O is handled separately and uses standard macOS file permissions
    // However, we explicitly block a small set of critical system paths that should never be referenced
    let criticalSystemPaths = [
      "/etc",
      "/private/etc",
      "/System/Library/LaunchDaemons",
      "/usr/bin/sudo",
    ]

    for criticalPath in criticalSystemPaths {
      if normalizedPath == criticalPath || normalizedPath.hasPrefix(criticalPath + "/") {
        return nil
      }
    }

    // Additional checks for suspicious patterns in decoded path
    let pathToCheck = decodedPath.lowercased()
    let suspiciousPatterns = [
      "\\x", "\\u",  // Escape sequences
      "//", "\\\\",  // Double slashes
      "\r", "\n", "\t",  // Control characters
    ]

    for pattern in suspiciousPatterns {
      if pathToCheck.contains(pattern.lowercased()) {
        return nil
      }
    }

    return normalizedPath
  }

  /// Sanitize and validate a user-provided string (names, identifiers, etc.)
  static func sanitizeString(_ input: String) -> String? {
    // Limit string length to prevent resource exhaustion
    guard input.count <= 256 else {
      return nil  // String too long
    }

    // Check for null bytes
    if input.contains("\0") {
      return nil
    }

    // Check for dangerous patterns that could indicate injection attempts
    let dangerousPatterns = [
      "$(",  // Command substitution
      "`",  // Command substitution (backticks)
      "${",  // Variable expansion
      ";",  // Command separator
      "&&",  // Command chaining
      "||",  // Command chaining OR
      "|",  // Pipe
      ">",  // File redirection
      "<",  // File input redirection
      "eval ",  // Code evaluation
      "exec ",  // Process execution
      "\n",  // Newlines for injection
      "\r",  // Carriage returns
      "../",  // Path traversal attempts
      "~",  // Home directory expansion
      "\\x", "\\u",  // Encoded sequences
      "%2e", "%2f", "%5c",  // URL-encoded dangerous chars
    ]

    let inputLower = input.lowercased()
    for pattern in dangerousPatterns {
      if inputLower.contains(pattern.lowercased()) {
        return nil  // Reject dangerous input
      }
    }

    return input
  }

  /// Validate a user-provided path and throw appropriate error if invalid
  static func validatePath(_ path: String) throws -> String {
    guard let validPath = sanitizePath(path) else {
      throw ProjectError.invalidArguments("Invalid or potentially unsafe path: \(path)")
    }
    return validPath
  }

  /// Validate a user-provided string and throw appropriate error if invalid
  static func validateString(_ input: String) throws -> String {
    guard let validString = sanitizeString(input) else {
      throw ProjectError.invalidArguments("Invalid or potentially unsafe string: \(input)")
    }
    return validString
  }

  /// Validate product name for security (targets, products, etc.)
  static func validateProductNameSecurity(_ name: String) throws {
    // Check for empty or whitespace-only names
    guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw ProjectError.invalidArguments("Product name cannot be empty or whitespace")
    }

    // Check for reasonable length (max 255 characters)
    guard name.count <= 255 else {
      throw ProjectError.invalidArguments("Product name cannot exceed 255 characters")
    }

    // Check for path traversal attempts
    guard !name.contains("../") && !name.contains("..\\") else {
      throw ProjectError.invalidArguments("Product name cannot contain path traversal sequences")
    }

    // Check for invalid characters that could cause issues
    let invalidCharacters = CharacterSet(charactersIn: "<>:\"|?*")
    guard name.rangeOfCharacter(from: invalidCharacters) == nil else {
      throw ProjectError.invalidArguments("Product name contains invalid characters (<>:\"|?*)")
    }

    // Check for control characters
    guard name.rangeOfCharacter(from: .controlCharacters) == nil else {
      throw ProjectError.invalidArguments("Product name cannot contain control characters")
    }

    // Check for null bytes
    guard !name.contains("\0") else {
      throw ProjectError.invalidArguments("Product name cannot contain null bytes")
    }
  }

  /// Sanitize path using PathUtils validation (avoiding circular imports) - DEPRECATED
  private static func deprecatedSanitizePath(_ path: String) -> String? {
    // Basic path traversal check (subset of PathUtils logic to avoid circular import)
    if path.contains("../") || path.contains("..\\") || path.hasPrefix("../") {
      return nil
    }
    return path
  }
}
