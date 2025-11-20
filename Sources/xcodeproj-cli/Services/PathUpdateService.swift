//
// PathUpdateService.swift
// xcodeproj-cli
//

import Foundation
@preconcurrency import XcodeProj

/// Service for updating file paths in the project
@MainActor
final class PathUpdateService {
  private let pbxproj: PBXProj

  init(pbxproj: PBXProj) {
    self.pbxproj = pbxproj
  }

  // MARK: - Path Update Methods

  func updateFilePaths(_ mappings: [String: String]) {
    var count = 0

    for fileRef in pbxproj.fileReferences {
      guard let oldPath = fileRef.path,
        let newPath = mappings[oldPath],
        let sanitized = sanitizePath(newPath)
      else { continue }

      fileRef.path = sanitized
      count += 1
      print("📝 Updated \(oldPath) -> \(sanitized)")
    }

    print("✅ Updated \(count) file paths")
  }

  func updatePathsWithPrefix(from oldPrefix: String, to newPrefix: String) {
    var mappings: [String: String] = [:]

    for fileRef in pbxproj.fileReferences {
      guard let path = fileRef.path,
        path.hasPrefix(oldPrefix)
      else { continue }

      mappings[path] = path.replacingOccurrences(of: oldPrefix, with: newPrefix)
    }

    updateFilePaths(mappings)
  }
}
