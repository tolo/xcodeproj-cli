//
// PathUtils.swift
// xcodeproj-cli
//
// Path manipulation and validation utilities
//

import Foundation
@preconcurrency import XcodeProj

/// Path manipulation and security utilities
struct PathUtils {

  /// Sanitize and validate a file path for security
  /// Delegates to SecurityUtils for the actual implementation
  static func sanitizePath(_ path: String) -> String? {
    return SecurityUtils.sanitizePath(path)
  }

  /// Validate a file path and throw appropriate error if invalid
  static func validatePath(_ path: String) throws -> String {
    guard let validPath = sanitizePath(path) else {
      throw ProjectError.invalidArguments("Invalid file path: \(path)")
    }
    return validPath
  }

  /// Check if a file should be included based on filtering rules
  static func shouldIncludeFile(_ path: String) -> Bool {
    let filename = (path as NSString).lastPathComponent
    let excludedFiles = [".DS_Store", "Thumbs.db", ".git", ".gitignore", ".gitkeep"]
    let excludedExtensions = [".orig", ".bak", ".tmp", ".temp"]

    // Skip hidden files (starting with .)
    if filename.hasPrefix(".") && !filename.hasSuffix(".h") && !filename.hasSuffix(".m") {
      return false
    }

    // Skip excluded files
    if excludedFiles.contains(filename) {
      return false
    }

    // Skip excluded extensions
    for ext in excludedExtensions {
      if filename.hasSuffix(ext) {
        return false
      }
    }

    return true
  }

  /// Check if file should be added to compile sources
  static func isCompilableFile(_ path: String) -> Bool {
    let compilableExtensions = ["swift", "m", "mm", "cpp", "cc", "cxx", "c"]
    return compilableExtensions.contains((path as NSString).pathExtension.lowercased())
  }

  /// Match a file reference against a search path with multiple strategies
  /// Returns true if the file reference matches the search path
  /// Supports: exact match, filename match, and partial path match
  static func fileReferenceMatches(fileRef: PBXFileReference, searchPath: String) -> Bool {
    // Handle empty search path
    guard !searchPath.isEmpty else {
      return false
    }

    // Strategy 1: Exact path or name match
    if fileRef.path == searchPath || fileRef.name == searchPath {
      return true
    }

    // Strategy 2: Filename-only match (most specific)
    let searchFileName = (searchPath as NSString).lastPathComponent
    let refFileName = ((fileRef.path ?? fileRef.name ?? "") as NSString).lastPathComponent

    // Only match if search is filename only (no path separators) and filenames match exactly
    if !searchPath.contains("/") && !searchFileName.isEmpty && searchFileName == refFileName {
      return true
    }

    // Strategy 3: Partial path match (must match path components exactly)
    if let refPath = fileRef.path ?? fileRef.name {
      // Split paths into components for precise matching
      let searchComponents = searchPath.split(separator: "/").map(String.init)
      let refComponents = refPath.split(separator: "/").map(String.init)

      // Check if search path components appear in order at the end of ref path
      if searchComponents.count <= refComponents.count && searchComponents.count > 1 {
        let startIndex = refComponents.count - searchComponents.count
        let refSuffix = Array(refComponents[startIndex...])
        if refSuffix == searchComponents {
          return true
        }
      }
    }

    return false
  }

  /// Find the best matching file reference for a given search path
  /// Returns the most specific match if multiple files match
  static func findBestFileMatch(in fileRefs: [PBXFileReference], searchPath: String)
    -> PBXFileReference?
  {
    let matches = fileRefs.filter { fileReferenceMatches(fileRef: $0, searchPath: searchPath) }

    // If no matches or single match, return immediately
    if matches.count <= 1 {
      return matches.first
    }

    // Multiple matches - prefer more specific matches
    // Priority: exact path > exact name > longer path > shorter path
    let sorted = matches.sorted { ref1, ref2 in
      // Exact path match takes highest priority
      if ref1.path == searchPath { return true }
      if ref2.path == searchPath { return false }

      // Exact name match is next priority
      if ref1.name == searchPath { return true }
      if ref2.name == searchPath { return false }

      // Prefer longer paths (more specific)
      let path1 = ref1.path ?? ref1.name ?? ""
      let path2 = ref2.path ?? ref2.name ?? ""
      return path1.count > path2.count
    }

    return sorted.first
  }

  /// Compute relative path from group to file for PBXFileReference.path storage
  /// This matches how Xcode stores file references relative to their parent group
  /// - Parameters:
  ///   - groupPath: Logical group path (e.g., "Sources/Models")
  ///   - filePath: Absolute or relative file path
  /// - Returns: Relative path suitable for PBXFileReference.path
  static func computeRelativePath(fromGroup groupPath: String, toFile filePath: String) -> String {
    let fileName = (filePath as NSString).lastPathComponent

    // If groupPath is empty, return just the filename
    guard !groupPath.isEmpty else {
      return fileName
    }

    // Split paths into components
    let groupComponents = groupPath.split(separator: "/").map(String.init)
    let filePathComponents = filePath.split(separator: "/").map(String.init)

    // If file path has fewer components than group path, just return filename
    guard filePathComponents.count > groupComponents.count else {
      return fileName
    }

    // Try to find where the group path matches in the file path
    // Look for the group components appearing consecutively in the file path
    var matchIndex: Int?
    for i in 0...(filePathComponents.count - groupComponents.count) {
      let slice = Array(filePathComponents[i..<(i + groupComponents.count)])
      if slice == groupComponents {
        matchIndex = i
        break
      }
    }

    // If we found a match, return the path components after the match
    if let matchIndex = matchIndex {
      let startIndex = matchIndex + groupComponents.count
      if startIndex < filePathComponents.count {
        let relativeComponents = Array(filePathComponents[startIndex...])
        return relativeComponents.joined(separator: "/")
      }
    }

    // If no match found, return just the filename
    // This handles cases where the file path doesn't contain the group path
    return fileName
  }
}
