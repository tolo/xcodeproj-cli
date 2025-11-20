//
// FileService.swift
// xcodeproj-cli
//

import Foundation
@preconcurrency import PathKit
@preconcurrency import XcodeProj

/// Service for file operations in Xcode projects
@MainActor
final class FileService {
  private let pbxproj: PBXProj
  private let cacheManager: CacheManager
  private let buildPhaseManager: BuildPhaseManager
  private let profiler: PerformanceProfiler?
  private let pathResolver: PathResolver

  // Dependencies for group operations
  private weak var groupService: GroupService?

  init(
    pbxproj: PBXProj,
    projectPath: Path,
    cacheManager: CacheManager,
    buildPhaseManager: BuildPhaseManager,
    profiler: PerformanceProfiler? = nil
  ) {
    self.pbxproj = pbxproj
    self.cacheManager = cacheManager
    self.buildPhaseManager = buildPhaseManager
    self.profiler = profiler

    // Get project directory (parent of .xcodeproj)
    let projectDir = projectPath.parent()
    self.pathResolver = PathResolver(pbxproj: pbxproj, projectDir: projectDir)
  }

  // Inject GroupService after initialization to avoid circular dependency
  func setGroupService(_ groupService: GroupService) {
    self.groupService = groupService
  }

  // MARK: - Helper Methods

  /// Computes the relative path from a group to a file using filesystem resolution
  private func computeRelativePath(fromGroup group: PBXGroup, toFile absoluteFilePath: String)
    -> String
  {
    let fileName = (absoluteFilePath as NSString).lastPathComponent

    // Resolve the group's absolute filesystem path
    guard let groupAbsolutePath = pathResolver.resolveGroupPath(for: group) else {
      // Group has no filesystem path (organizational only), use just the filename
      return fileName
    }

    let filePathString = absoluteFilePath
    let groupPathString = groupAbsolutePath.string

    // Normalize paths (ensure they end with / for directory comparison)
    let normalizedGroupPath =
      groupPathString.hasSuffix("/") ? groupPathString : groupPathString + "/"

    // Check if file is within the group's directory
    if filePathString.hasPrefix(normalizedGroupPath) {
      // File is within group directory, get the relative portion
      let relativePath = String(filePathString.dropFirst(normalizedGroupPath.count))
      return relativePath.isEmpty ? fileName : relativePath
    } else if filePathString.hasPrefix(groupPathString + "/") {
      // Handle case where group path doesn't have trailing slash
      let relativePath = String(filePathString.dropFirst((groupPathString + "/").count))
      return relativePath.isEmpty ? fileName : relativePath
    }

    // File is outside the group's directory, compute relative path manually
    let fileComponents = filePathString.split(separator: "/").map(String.init)
    let groupComponents = groupPathString.split(separator: "/").map(String.init)

    // Find common prefix
    var commonPrefixLength = 0
    for (index, component) in groupComponents.enumerated() {
      if index < fileComponents.count && fileComponents[index] == component {
        commonPrefixLength += 1
      } else {
        break
      }
    }

    // Build relative path with ../ for each remaining group component
    let parentDirs = Array(repeating: "..", count: groupComponents.count - commonPrefixLength)
    let remainingFilePath = Array(fileComponents.dropFirst(commonPrefixLength))
    let relativeComponents = parentDirs + remainingFilePath

    return relativeComponents.isEmpty ? fileName : relativeComponents.joined(separator: "/")
  }

  // MARK: - File Operations

  func addFile(path: String, to groupPath: String, targets: [String]) throws {
    try profiler?.measureOperation("addFile-\(path)") {
      try _addFile(path: path, to: groupPath, targets: targets)
    } ?? _addFile(path: path, to: groupPath, targets: targets)
  }

  private func _addFile(path: String, to groupPath: String, targets: [String]) throws {
    // Validate path
    guard sanitizePath(path) != nil else {
      throw ProjectError.invalidArguments("Invalid file path: \(path)")
    }

    // Check if file exists on filesystem
    guard FileManager.default.fileExists(atPath: path) else {
      throw ProjectError.operationFailed("File not found: \(path)")
    }

    let fileName = (path as NSString).lastPathComponent

    // Find parent group using cache or path-aware lookup
    guard
      let parentGroup = cacheManager.getGroup(groupPath)
        ?? groupService?.findGroupByNameOrPath(groupPath)
    else {
      throw ProjectError.groupNotFound(groupPath)
    }

    // Compute relative path using filesystem resolution
    let relativePath = computeRelativePath(fromGroup: parentGroup, toFile: path)

    // Check if file already exists in this specific group using relative path
    let fileExistsInGroup = parentGroup.children.contains { child in
      if let fileRef = child as? PBXFileReference {
        return fileRef.path == relativePath
      }
      return false
    }

    if fileExistsInGroup {
      print("⚠️  File \(relativePath) already exists in group \(groupPath), skipping")
      return
    }

    // Create unique cache key combining group and relative path
    let cacheKey = "\(groupPath)/\(relativePath)"

    // Check global cache with unique key
    if cacheManager.getFileReference(cacheKey) != nil {
      print("⚠️  File \(relativePath) already exists, skipping")
      return
    }

    // Create file reference with relative path and display name
    let fileRef = PBXFileReference(
      sourceTree: .group,
      name: fileName,
      lastKnownFileType: fileType(for: path),
      path: relativePath
    )

    // Add to project
    pbxproj.add(object: fileRef)
    parentGroup.children.append(fileRef)

    // Invalidate cache since we added a new file (use unique key)
    cacheManager.invalidateFileReference(cacheKey)

    // Add to targets using BuildPhaseManager
    buildPhaseManager.addFileToBuildPhases(
      fileReference: fileRef,
      targets: targets,
      isCompilable: isCompilableFile(path)
    )

    print("✅ Added \(fileName) to \(targets.joined(separator: ", "))")
  }

  func addFiles(_ files: [(path: String, group: String)], to targets: [String]) throws {
    guard !files.isEmpty else { return }

    // Batch operation with single save at the end
    try profiler?.measureOperation("addFiles-batch-\(files.count)") {
      try _addFilesBatch(files, to: targets)
    } ?? _addFilesBatch(files, to: targets)
  }

  private func _addFilesBatch(_ files: [(path: String, group: String)], to targets: [String]) throws
  {
    print("📁 Adding \(files.count) files in batch...")

    var addedFiles = 0
    var skippedFiles = 0

    for (path, groupPath) in files {
      do {
        // Validate path
        guard sanitizePath(path) != nil else {
          throw ProjectError.invalidArguments("Invalid file path: \(path)")
        }

        // Check if file exists on filesystem
        guard FileManager.default.fileExists(atPath: path) else {
          throw ProjectError.operationFailed("File not found: \(path)")
        }

        let fileName = (path as NSString).lastPathComponent

        // Find parent group using cache or path-aware lookup
        guard
          let parentGroup = cacheManager.getGroup(groupPath)
            ?? groupService?.findGroupByNameOrPath(groupPath)
        else {
          throw ProjectError.groupNotFound(groupPath)
        }

        // Compute relative path using filesystem resolution
        let relativePath = computeRelativePath(fromGroup: parentGroup, toFile: path)

        // Check if file already exists in this specific group using relative path
        let fileExistsInGroup = parentGroup.children.contains { child in
          if let fileRef = child as? PBXFileReference {
            return fileRef.path == relativePath
          }
          return false
        }

        if fileExistsInGroup {
          print("⚠️  File \(relativePath) already exists in group \(groupPath), skipping")
          skippedFiles += 1
          continue
        }

        // Create unique cache key combining group and relative path
        let cacheKey = "\(groupPath)/\(relativePath)"

        // Check global cache with unique key
        if cacheManager.getFileReference(cacheKey) != nil {
          print("⚠️  File \(relativePath) already exists, skipping")
          skippedFiles += 1
          continue
        }

        // Create file reference with relative path and display name
        let fileRef = PBXFileReference(
          sourceTree: .group,
          name: fileName,
          lastKnownFileType: fileType(for: path),
          path: relativePath
        )

        // Add to project
        pbxproj.add(object: fileRef)
        parentGroup.children.append(fileRef)

        // Invalidate cache since we added a new file (use unique key)
        cacheManager.invalidateFileReference(cacheKey)

        // Add to targets using BuildPhaseManager
        buildPhaseManager.addFileToBuildPhases(
          fileReference: fileRef,
          targets: targets,
          isCompilable: isCompilableFile(path)
        )

        addedFiles += 1

        if profiler != nil {
          print("  ✅ Added \(fileName) (\(addedFiles)/\(files.count))")
        }
      } catch {
        print("❌ Failed to add \(path): \(error.localizedDescription)")
        throw error
      }
    }

    print("✅ Batch complete: \(addedFiles) added, \(skippedFiles) skipped")
  }

  // MARK: - Target-Only File Operations

  func addFileToTarget(path: String, targetName: String) throws {
    // Find the file reference using improved matching logic
    guard
      let fileRef = PathUtils.findBestFileMatch(in: Array(pbxproj.fileReferences), searchPath: path)
    else {
      throw ProjectError.operationFailed(
        "File not found in project: \(path). File must already exist in the project to add to targets."
      )
    }

    // Add to target using BuildPhaseManager
    buildPhaseManager.addFileToBuildPhases(
      fileReference: fileRef,
      targets: [targetName],
      isCompilable: isCompilableFile(path)
    )

    let fileName = fileRef.path ?? fileRef.name ?? path
    print("✅ Added \(fileName) to target: \(targetName)")
  }

  func removeFileFromTarget(path: String, targetName: String) throws {
    // Find the file reference using improved matching logic
    guard
      let fileRef = PathUtils.findBestFileMatch(in: Array(pbxproj.fileReferences), searchPath: path)
    else {
      throw ProjectError.operationFailed("File not found in project: \(path)")
    }

    let fileName = (path as NSString).lastPathComponent

    guard let target = pbxproj.nativeTargets.first(where: { $0.name == targetName }) else {
      throw ProjectError.targetNotFound(targetName)
    }

    // Remove from all build phases of this target
    for buildPhase in target.buildPhases {
      switch buildPhase {
      case let sourcesBuildPhase as PBXSourcesBuildPhase:
        if let buildFile = sourcesBuildPhase.files?.first(where: { $0.file === fileRef }) {
          sourcesBuildPhase.files?.removeAll { $0 === buildFile }
          pbxproj.delete(object: buildFile)
        }
      case let resourcesBuildPhase as PBXResourcesBuildPhase:
        if let buildFile = resourcesBuildPhase.files?.first(where: { $0.file === fileRef }) {
          resourcesBuildPhase.files?.removeAll { $0 === buildFile }
          pbxproj.delete(object: buildFile)
        }
      case let frameworksBuildPhase as PBXFrameworksBuildPhase:
        if let buildFile = frameworksBuildPhase.files?.first(where: { $0.file === fileRef }) {
          frameworksBuildPhase.files?.removeAll { $0 === buildFile }
          pbxproj.delete(object: buildFile)
        }
      case let copyFilesBuildPhase as PBXCopyFilesBuildPhase:
        if let buildFile = copyFilesBuildPhase.files?.first(where: { $0.file === fileRef }) {
          copyFilesBuildPhase.files?.removeAll { $0 === buildFile }
          pbxproj.delete(object: buildFile)
        }
      default:
        continue
      }
    }

    print("✅ Removed \(fileName) from target: \(targetName)")
  }

  // MARK: - File Management (Move/Remove)

  func moveFile(from oldPath: String, to newPath: String) throws {
    guard
      let fileRef = pbxproj.fileReferences.first(where: { $0.path == oldPath || $0.name == oldPath }
      )
    else {
      throw ProjectError.operationFailed("File not found: \(oldPath)")
    }

    let newName = (newPath as NSString).lastPathComponent
    fileRef.path = newName
    if fileRef.name == nil || fileRef.name == oldPath {
      fileRef.name = newName
    }

    print("✅ Moved \(oldPath) -> \(newPath)")
  }

  func moveFileToGroup(filePath: String, targetGroup: String) throws {
    // Find the file reference
    let fileName = (filePath as NSString).lastPathComponent
    guard
      let fileRef = pbxproj.fileReferences.first(where: {
        $0.path == fileName || $0.name == fileName || $0.path == filePath || $0.name == filePath
      })
    else {
      throw ProjectError.operationFailed("File not found: \(filePath)")
    }

    // Find current parent group
    var currentParentGroup: PBXGroup?
    for group in pbxproj.groups {
      if group.children.contains(where: { $0 === fileRef }) {
        currentParentGroup = group
        break
      }
    }

    // Find target group
    guard let targetPBXGroup = findGroup(named: targetGroup, in: pbxproj.groups) else {
      throw ProjectError.groupNotFound(targetGroup)
    }

    // Remove from current group if found
    if let currentGroup = currentParentGroup {
      currentGroup.children.removeAll { $0 === fileRef }
    }

    // Add to target group
    targetPBXGroup.children.append(fileRef)

    print("✅ Moved \(fileName) to group \(targetGroup)")
  }

  func removeFile(_ filePath: String) throws {
    // Try to find the file reference by exact match or by filename
    let fileName = (filePath as NSString).lastPathComponent

    guard
      let fileRef = pbxproj.fileReferences.first(where: {
        // Check exact path match
        $0.path == filePath
          // Check name match
          || $0.name == filePath
          // Check filename match (just the last component)
          || $0.path == fileName || $0.name == fileName
          // Check if the path ends with the provided path (for partial paths like "Sources/File.swift")
          || ($0.path?.hasSuffix(filePath) ?? false)
      })
    else {
      throw ProjectError.operationFailed("File not found: \(filePath)")
    }

    // Collect all build files that reference this file
    // Using Array instead of Set to avoid crashes with duplicate PBXBuildFile elements
    let buildFilesToDelete = buildPhaseManager.findBuildFiles(for: fileRef)

    // Remove from all groups
    for group in pbxproj.groups {
      group.children.removeAll { $0 === fileRef }
    }

    // Remove build files from all build phases
    buildPhaseManager.removeBuildFiles { buildFile in
      buildFilesToDelete.contains(where: { $0 === buildFile })
    }

    // Delete all collected build files from the project
    for buildFile in buildFilesToDelete {
      pbxproj.delete(object: buildFile)
    }

    // Remove from project
    pbxproj.delete(object: fileRef)

    print("✅ Removed \(fileRef.path ?? fileRef.name ?? filePath)")
  }

  // MARK: - Folder Operations

  func addFolder(
    folderPath: String, to groupPath: String, targets: [String], recursive: Bool = true,
    ensureGroupHierarchyFunc: (String) throws -> PBXGroup?
  ) throws {
    let folderURL = URL(fileURLWithPath: folderPath)

    // Ensure the folder exists
    guard FileManager.default.fileExists(atPath: folderPath) else {
      throw ProjectError.operationFailed("Folder not found: \(folderPath)")
    }

    let folderName = folderURL.lastPathComponent
    print("📁 Adding folder: \(folderName)")

    // Create group for the folder
    let fullGroupPath = groupPath.isEmpty ? folderName : "\(groupPath)/\(folderName)"
    guard let folderGroup = try ensureGroupHierarchyFunc(fullGroupPath) else {
      throw ProjectError.operationFailed("Could not create group hierarchy: \(fullGroupPath)")
    }

    // Add files from folder
    try addFilesFromFolder(
      folderURL, to: folderGroup, groupPath: fullGroupPath, targets: targets, recursive: recursive,
      ensureGroupHierarchyFunc: ensureGroupHierarchyFunc)

    print("✅ Added folder \(folderName) with all contents")
  }

  private func addFilesFromFolder(
    _ folderURL: URL, to group: PBXGroup, groupPath: String, targets: [String], recursive: Bool,
    ensureGroupHierarchyFunc: (String) throws -> PBXGroup?
  ) throws {
    let fileManager = FileManager.default

    guard
      let enumerator = fileManager.enumerator(
        at: folderURL,
        includingPropertiesForKeys: [.isDirectoryKey, .nameKey],
        options: recursive ? [] : [.skipsSubdirectoryDescendants])
    else {
      throw ProjectError.operationFailed("Could not enumerate folder contents")
    }

    for case let fileURL as URL in enumerator {
      let relativePath = String(fileURL.path.dropFirst(folderURL.path.count + 1))

      // Skip if file should be excluded
      if !shouldIncludeFile(fileURL.lastPathComponent) {
        continue
      }

      var isDirectory: ObjCBool = false
      fileManager.fileExists(atPath: fileURL.path, isDirectory: &isDirectory)

      if isDirectory.boolValue {
        // Create subgroup for subdirectory
        if recursive {
          let subgroupName = fileURL.lastPathComponent
          let subgroupPath = "\(groupPath)/\(subgroupName)"

          if let subgroup = try ensureGroupHierarchyFunc(subgroupPath) {
            try addFilesFromFolder(
              fileURL, to: subgroup, groupPath: subgroupPath, targets: targets,
              recursive: recursive,
              ensureGroupHierarchyFunc: ensureGroupHierarchyFunc
            )
          }
        }
      } else {
        // Add file to current group
        let fileName = fileURL.lastPathComponent

        // Check if file already exists
        if fileExists(path: fileName, in: pbxproj) {
          print("⚠️  File \(fileName) already exists, skipping")
          continue
        }

        // Create file reference with relative path
        let fileRef = PBXFileReference(
          sourceTree: .group,
          lastKnownFileType: fileType(for: fileName),
          path: fileName
        )

        // Add to project and group
        pbxproj.add(object: fileRef)
        group.children.append(fileRef)

        // Add to targets using BuildPhaseManager
        buildPhaseManager.addFileToBuildPhases(
          fileReference: fileRef,
          targets: targets,
          isCompilable: isCompilableFile(fileName)
        )

        print("  📄 Added: \(relativePath)")
      }
    }
  }

  // MARK: - Synchronized Folder

  func addSynchronizedFolder(folderPath: String, to groupPath: String, targets: [String]) throws {
    let folderURL = URL(fileURLWithPath: folderPath)
    let folderName = folderURL.lastPathComponent

    // Ensure the folder exists
    guard FileManager.default.fileExists(atPath: folderPath) else {
      throw ProjectError.operationFailed("Folder not found: \(folderPath)")
    }

    // Find parent group
    guard let parentGroup = findGroup(named: groupPath, in: pbxproj.groups) else {
      throw ProjectError.groupNotFound(groupPath)
    }

    // Create a filesystem synchronized root group (Xcode 16+)
    let syncGroup = PBXFileSystemSynchronizedRootGroup(
      sourceTree: .group,
      path: folderName,
      name: folderName
    )

    // Add to project and parent group
    pbxproj.add(object: syncGroup)
    parentGroup.children.append(syncGroup)

    // For each target, we need to add the sync group to the sources build phase
    for targetName in targets {
      guard let target = pbxproj.nativeTargets.first(where: { $0.name == targetName }) else {
        print("⚠️  Target '\(targetName)' not found")
        continue
      }

      // Find or create sources build phase
      let sourcesBuildPhase =
        target.buildPhases.first(where: { $0 is PBXSourcesBuildPhase }) as? PBXSourcesBuildPhase
        ?? {
          let phase = PBXSourcesBuildPhase()
          pbxproj.add(object: phase)
          target.buildPhases.append(phase)
          return phase
        }()

      // Add the synchronized group as a build file
      let buildFile = PBXBuildFile(file: syncGroup)
      pbxproj.add(object: buildFile)
      sourcesBuildPhase.files?.append(buildFile)

      print("📁 Added synchronized folder to target: \(targetName)")
    }

    print("✅ Added filesystem synchronized folder: \(folderName) (auto-syncs with filesystem)")
  }
}
