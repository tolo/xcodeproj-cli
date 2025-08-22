//
// PathResolver.swift
// xcodeproj-cli
//
// Handles path resolution for Xcode project file references
//

import Foundation
@preconcurrency import PathKit
@preconcurrency import XcodeProj

/// Handles path resolution and validation for Xcode project file references
class PathResolver {
  private let pbxproj: PBXProj
  private let projectDir: Path
  private let fileManager: FileManager

  init(pbxproj: PBXProj, projectDir: Path, fileManager: FileManager = FileManager.default) {
    self.pbxproj = pbxproj
    self.projectDir = projectDir
    self.fileManager = fileManager
  }

  /// Resolves the absolute file system path for a file reference within its group context
  func resolveFilePath(for fileRef: PBXFileReference, in group: PBXGroup?) -> Path? {
    // Get the path from the file reference
    guard let filePath = fileRef.path ?? fileRef.name else { return nil }

    // Validate path for security
    guard SecurityUtils.sanitizePath(filePath) != nil else {
      print("⚠️  Warning: Invalid or potentially unsafe path provided")
      return nil
    }

    // Start with project directory
    var basePath = projectDir

    // If file has a source tree, handle it
    if let sourceTree = fileRef.sourceTree {
      switch sourceTree {
      case .absolute:
        return Path(filePath)
      case .group:
        // Need to calculate path from group hierarchy
        if let group = group {
          var groupPath = Path("")
          var currentGroup: PBXGroup? = group
          var pathComponents: [String] = []

          // Build path from group hierarchy
          while let g = currentGroup {
            if let path = g.path, !path.isEmpty {
              pathComponents.insert(path, at: 0)
            }
            // Find parent group
            currentGroup = pbxproj.groups.first { parent in
              parent.children.contains { $0 === g }
            }
          }

          for component in pathComponents {
            // Validate each path component for security
            guard SecurityUtils.sanitizePath(component) != nil else {
              print("⚠️  Warning: Invalid path component provided")
              return nil
            }
            groupPath = groupPath + Path(component)
          }
          basePath = basePath + groupPath
        }
      case .sourceRoot:
        // Relative to project root
        basePath = projectDir
      default:
        break
      }
    }

    return basePath + Path(filePath)
  }

  /// Resolves the absolute file system path for a group (folder reference)
  func resolveGroupPath(for group: PBXGroup) -> Path? {
    // Skip groups without a path (they're just organizational)
    guard let groupPath = group.path, !groupPath.isEmpty else { return nil }

    // Validate path for security
    guard SecurityUtils.sanitizePath(groupPath) != nil else {
      print("⚠️  Warning: Invalid or potentially unsafe group path provided")
      return nil
    }

    var basePath = projectDir
    var pathComponents: [String] = []
    var currentGroup: PBXGroup? = group

    // Build path from group hierarchy
    while let g = currentGroup {
      if let path = g.path, !path.isEmpty {
        pathComponents.insert(path, at: 0)
      }
      // Find parent group
      currentGroup = pbxproj.groups.first { parent in
        parent.children.contains { $0 === g }
      }
    }

    for component in pathComponents {
      // Validate each path component for security
      guard SecurityUtils.sanitizePath(component) != nil else {
        print("⚠️  Warning: Invalid path component in group provided")
        return nil
      }
      basePath = basePath + Path(component)
    }

    return basePath
  }

  /// Checks if a path exists on the file system
  func isValidPath(_ path: Path) -> Bool {
    return fileManager.fileExists(atPath: path.string)
  }

  /// Gets the absolute path for a file reference based on its source tree
  func getAbsolutePath(for fileRef: PBXFileReference) -> Path? {
    guard let filePath = fileRef.path ?? fileRef.name else { return nil }

    // Validate path for security
    guard SecurityUtils.sanitizePath(filePath) != nil else {
      print("⚠️  Warning: Invalid or potentially unsafe file path provided")
      return nil
    }

    if let sourceTree = fileRef.sourceTree {
      switch sourceTree {
      case .absolute:
        return Path(filePath)
      case .sourceRoot:
        return projectDir + Path(filePath)
      case .group:
        // For group-relative paths, we need the group context
        // This method assumes the file is at the root level for group source tree
        return projectDir + Path(filePath)
      default:
        break
      }
    }

    // Default to relative to project directory
    return projectDir + Path(filePath)
  }

  /// Determines if a file reference represents a folder based on its type
  func isFileReferenceFolder(_ fileRef: PBXFileReference) -> Bool {
    return fileRef.lastKnownFileType == "folder"
      || fileRef.lastKnownFileType == "folder.assetcatalog"
      || fileRef.lastKnownFileType == "wrapper.framework"
  }

  /// Validates a file reference against the file system
  /// Returns nil if valid, or an issue description if invalid
  func validateFileReference(_ fileRef: PBXFileReference, in group: PBXGroup?) -> String? {
    guard let absolutePath = resolveFilePath(for: fileRef, in: group) else {
      return "Could not resolve path"
    }

    let pathString = absolutePath.string

    // Check if file exists
    if !fileManager.fileExists(atPath: pathString) {
      return "File not found at: \(pathString)"
    }

    // Check if it's a directory when it shouldn't be or vice versa
    var isDirectory: ObjCBool = false
    fileManager.fileExists(atPath: pathString, isDirectory: &isDirectory)

    let isFolder = isFileReferenceFolder(fileRef)

    if isFolder && !isDirectory.boolValue {
      return "Expected directory but found file at: \(pathString)"
    } else if !isFolder && isDirectory.boolValue && fileRef.lastKnownFileType != nil {
      return "Expected file but found directory at: \(pathString)"
    }

    return nil  // Valid
  }

  /// Validates a group against the file system
  /// Returns nil if valid, or an issue description if invalid
  func validateGroup(_ group: PBXGroup) -> String? {
    guard let absolutePath = resolveGroupPath(for: group) else {
      return nil  // Groups without paths are just organizational
    }

    let pathString = absolutePath.string

    if !fileManager.fileExists(atPath: pathString) {
      return "Folder not found at: \(pathString)"
    }

    // Check if it's actually a directory
    var isDirectory: ObjCBool = false
    fileManager.fileExists(atPath: pathString, isDirectory: &isDirectory)
    if !isDirectory.boolValue {
      return "Expected folder but found file at: \(pathString)"
    }

    return nil  // Valid
  }
}
