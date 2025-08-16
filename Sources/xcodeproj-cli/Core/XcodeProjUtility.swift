//
// XcodeProjUtility.swift
// xcodeproj-cli
//
// Legacy utility class for Xcode project manipulation
// TODO: Gradually migrate functionality to XcodeProjService
//

import Foundation
@preconcurrency import PathKit
@preconcurrency import XcodeProj

@MainActor
class XcodeProjUtility {
  let xcodeproj: XcodeProj
  let projectPath: Path
  let pbxproj: PBXProj
  private var transactionBackupPath: Path?
  private lazy var buildPhaseManager = BuildPhaseManager(pbxproj: pbxproj)
  private let cacheManager: CacheManager
  private let profiler: PerformanceProfiler?

  init(path: String = "MyProject.xcodeproj", verbose: Bool = false) throws {
    // Resolve path relative to current working directory, not script location
    if path.hasPrefix("/") {
      // Absolute path
      self.projectPath = Path(path)
    } else {
      // Relative path - resolve from current working directory
      let currentDir = FileManager.default.currentDirectoryPath
      self.projectPath = Path(currentDir) + Path(path)
    }

    self.xcodeproj = try XcodeProj(path: projectPath)
    self.pbxproj = xcodeproj.pbxproj
    self.cacheManager = CacheManager(pbxproj: pbxproj)
    self.profiler = verbose ? PerformanceProfiler(verbose: verbose) : nil
  }

  // MARK: - Transaction Support
  func beginTransaction() throws {
    guard transactionBackupPath == nil else {
      throw ProjectError.operationFailed("Transaction already in progress")
    }

    let backupPath = Path("\(projectPath.string).transaction")
    if FileManager.default.fileExists(atPath: projectPath.string) {
      try FileManager.default.copyItem(atPath: projectPath.string, toPath: backupPath.string)
      transactionBackupPath = backupPath
      print("🔄 Transaction started")
    }
  }

  func commitTransaction() throws {
    guard let backupPath = transactionBackupPath else {
      return  // No transaction in progress
    }

    // Save changes first
    try save()

    // Remove backup - only clear transaction state after successful cleanup
    do {
      if FileManager.default.fileExists(atPath: backupPath.string) {
        try FileManager.default.removeItem(atPath: backupPath.string)
      }
      transactionBackupPath = nil
      print("✅ Transaction committed")
    } catch {
      // Backup cleanup failed - clear transaction state but log warning
      transactionBackupPath = nil
      print("⚠️  Transaction committed but backup cleanup failed: \(error.localizedDescription)")
      // Don't throw - the main operation (save) succeeded
    }
  }

  func rollbackTransaction() throws {
    guard let backupPath = transactionBackupPath else {
      throw ProjectError.operationFailed("No transaction to rollback")
    }

    // Restore from backup
    if FileManager.default.fileExists(atPath: backupPath.string) {
      if FileManager.default.fileExists(atPath: projectPath.string) {
        try FileManager.default.removeItem(atPath: projectPath.string)
      }
      try FileManager.default.moveItem(atPath: backupPath.string, toPath: projectPath.string)

      // Only clear transaction path after successful restore
      transactionBackupPath = nil
      print("↩️  Transaction rolled back")
    } else {
      // Backup doesn't exist - clear transaction state but warn
      transactionBackupPath = nil
      print("⚠️  Transaction backup not found - clearing transaction state")
    }
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

    // Check if file already exists using cache
    if cacheManager.getFileReference(fileName) != nil {
      print("⚠️  File \(fileName) already exists, skipping")
      return
    }

    // Find parent group using cache
    guard
      let parentGroup = cacheManager.getGroup(groupPath)
        ?? findGroup(named: groupPath, in: pbxproj.groups)
    else {
      throw ProjectError.groupNotFound(groupPath)
    }

    // Create file reference
    let fileRef = PBXFileReference(
      sourceTree: .group,
      lastKnownFileType: fileType(for: path),
      path: fileName
    )

    // Add to project
    pbxproj.add(object: fileRef)
    parentGroup.children.append(fileRef)

    // Invalidate cache since we added a new file
    cacheManager.invalidateFileReference(fileName)

    // Add to targets using BuildPhaseManager
    buildPhaseManager.addFileToBuildPhases(
      fileReference: fileRef,
      targets: targets,
      isCompilable: isCompilableFile(path)
    )

    print("✅ Added \(fileName) to \(targets.joined(separator: ", "))")
  }

  // MARK: - Folder Operations
  func addFolder(
    folderPath: String, to groupPath: String, targets: [String], recursive: Bool = true
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
    guard let folderGroup = ensureGroupHierarchy(fullGroupPath) else {
      throw ProjectError.operationFailed("Could not create group hierarchy: \(fullGroupPath)")
    }

    // Add files from folder
    try addFilesFromFolder(
      folderURL, to: folderGroup, groupPath: fullGroupPath, targets: targets, recursive: recursive)

    print("✅ Added folder \(folderName) with all contents")
  }

  private func addFilesFromFolder(
    _ folderURL: URL, to group: PBXGroup, groupPath: String, targets: [String], recursive: Bool
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

          if let subgroup = ensureGroupHierarchy(subgroupPath) {
            try addFilesFromFolder(
              fileURL, to: subgroup, groupPath: subgroupPath, targets: targets, recursive: recursive
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

  func removeGroup(_ groupPath: String) throws {
    // First try to find it as a regular group
    if let group = findGroup(named: groupPath, in: pbxproj.groups) {
      // Check if this is a special system group that shouldn't be removed
      if group === pbxproj.rootObject?.productsGroup {
        throw ProjectError.operationFailed("Cannot remove Products group - it's a system group")
      }
      if group === pbxproj.rootObject?.mainGroup {
        throw ProjectError.operationFailed(
          "Cannot remove '\(groupPath)' - it is the main project group. This would corrupt the project structure."
        )
      }

      removeGroupHierarchy(group)
      print("✅ Removed group '\(groupPath)'")
      return
    }

    // Try to find it as a file reference (folder reference)
    if let folderRef = pbxproj.fileReferences.first(where: {
      ($0.path == groupPath || $0.name == groupPath)
        && ($0.lastKnownFileType == "folder" || $0.lastKnownFileType == "folder.assetcatalog")
    }) {
      removeFolderReference(folderRef)
      print("✅ Removed folder reference '\(groupPath)'")
      return
    }

    // Try to find it as a synchronized folder
    if let syncGroup = pbxproj.fileSystemSynchronizedRootGroups.first(where: {
      $0.path == groupPath || $0.name == groupPath
    }) {
      removeSynchronizedFolder(syncGroup)
      print("✅ Removed synchronized folder '\(groupPath)'")
      return
    }

    throw ProjectError.groupNotFound(groupPath)
  }

  // MARK: - Utility Methods

  /// Adds an item to an array only if it's not already present (using identity comparison)
  private func addUniqueByIdentity<T: AnyObject>(_ item: T, to array: inout [T]) {
    if !array.contains(where: { $0 === item }) {
      array.append(item)
    }
  }

  // MARK: - Group Removal Helper Methods

  /// Contains collected contents from a group hierarchy
  private struct GroupContents {
    let filesToRemove: [PBXFileReference]
    let groupsToRemove: [PBXGroup]
    let variantGroupsToRemove: [PBXVariantGroup]
  }

  /// Recursively collects all files and subgroups from a group hierarchy
  private func collectGroupContents(from group: PBXGroup) -> GroupContents {
    var filesToRemove: [PBXFileReference] = []
    var groupsToRemove: [PBXGroup] = [group]
    var variantGroupsToRemove: [PBXVariantGroup] = []

    func collectFromGroup(_ group: PBXGroup) {
      for child in group.children {
        if let fileRef = child as? PBXFileReference {
          filesToRemove.append(fileRef)
        } else if let variantGroup = child as? PBXVariantGroup {
          variantGroupsToRemove.append(variantGroup)
          // Collect files from variant group
          for variantChild in variantGroup.children {
            if let variantFileRef = variantChild as? PBXFileReference {
              filesToRemove.append(variantFileRef)
            }
          }
        } else if let subgroup = child as? PBXGroup {
          groupsToRemove.append(subgroup)
          collectFromGroup(subgroup)
        }
      }
    }

    collectFromGroup(group)

    return GroupContents(
      filesToRemove: filesToRemove,
      groupsToRemove: groupsToRemove,
      variantGroupsToRemove: variantGroupsToRemove
    )
  }

  /// Removes file references from all build phases using BuildPhaseManager
  private func removeFilesFromBuildPhases(_ files: [PBXFileReference]) {
    // Collect all build files that need to be removed
    // Using Array instead of Set to avoid crashes with duplicate PBXBuildFile elements (XcodeProj 9.4.3 bug)
    // Uses ObjectIdentifier for O(1) duplicate detection performance
    var buildFilesToDelete: [PBXBuildFile] = []
    var seen = Set<ObjectIdentifier>()

    for fileRef in files {
      let foundBuildFiles = buildPhaseManager.findBuildFiles(for: fileRef)
      for buildFile in foundBuildFiles {
        let id = ObjectIdentifier(buildFile)
        if !seen.contains(id) {
          seen.insert(id)
          buildFilesToDelete.append(buildFile)
        }
      }
    }

    // Remove build files from their respective build phases
    buildPhaseManager.removeBuildFiles { buildFile in
      buildFilesToDelete.contains(where: { $0 === buildFile })
    }

    // Delete all collected build files from the project
    for buildFile in buildFilesToDelete {
      pbxproj.delete(object: buildFile)
    }
  }

  /// Deletes the group and all its collected contents from the project
  private func deleteGroupAndContents(_ group: PBXGroup, contents: GroupContents) {
    // Remove file references from project
    for fileRef in contents.filesToRemove {
      pbxproj.delete(object: fileRef)
    }

    // Remove variant groups from project
    for variantGroup in contents.variantGroupsToRemove {
      pbxproj.delete(object: variantGroup)
    }

    // Remove the group from its parent (including main project group)
    for parentGroup in pbxproj.groups {
      parentGroup.children.removeAll { $0 === group }
    }

    // Also check if the group is in the main project's mainGroup
    if let mainGroup = pbxproj.rootObject?.mainGroup {
      mainGroup.children.removeAll { $0 === group }
    }

    // Remove all groups from project
    for groupToRemove in contents.groupsToRemove {
      pbxproj.delete(object: groupToRemove)
    }
  }

  /// Removes a group hierarchy and all its contents from the project
  private func removeGroupHierarchy(_ group: PBXGroup) {
    // Step 1: Collect all contents from the group hierarchy
    let contents = collectGroupContents(from: group)

    // Step 2: Remove files from build phases
    removeFilesFromBuildPhases(contents.filesToRemove)

    // Step 3: Delete the group and all its contents
    deleteGroupAndContents(group, contents: contents)
  }

  private func removeFolderReference(_ folderRef: PBXFileReference) {
    // Collect all build files that reference this folder
    let buildFilesToDelete = buildPhaseManager.findBuildFiles(for: folderRef)

    // Remove from all groups
    for group in pbxproj.groups {
      group.children.removeAll { $0 === folderRef }
    }

    // Remove build files from build phases
    // Use identity comparison to match the fix pattern and avoid Set crashes
    buildPhaseManager.removeBuildFiles { buildFile in
      buildFilesToDelete.contains(where: { $0 === buildFile })
    }

    // Delete all collected build files from the project
    for buildFile in buildFilesToDelete {
      pbxproj.delete(object: buildFile)
    }

    // Remove the folder reference from project
    pbxproj.delete(object: folderRef)
  }

  private func removeSynchronizedFolder(_ syncGroup: PBXFileSystemSynchronizedRootGroup) {
    // Remove from parent groups
    for group in pbxproj.groups {
      group.children.removeAll { $0 === syncGroup }
    }

    // Remove from build phases if needed
    for target in pbxproj.nativeTargets {
      // Remove from build phase membership exceptions if present
      target.buildPhases.forEach { phase in
        if let sourcePhase = phase as? PBXSourcesBuildPhase {
          sourcePhase.files?.removeAll { file in
            // Check if this build file is related to the sync group
            if let fileRef = file.file as? PBXFileSystemSynchronizedRootGroup {
              return fileRef === syncGroup
            }
            return false
          }
        }
      }
    }

    // Remove the synchronized group from project
    pbxproj.delete(object: syncGroup)
  }

  func removeFolder(_ folderPath: String) throws {
    // Deprecated: This function now just calls removeGroup for consistency
    // Kept for backward compatibility
    try removeGroup(folderPath)
  }

  // Add synchronized folder reference (Xcode 16+ filesystem synchronized group)
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

  // MARK: - Target Management
  func addTarget(name: String, productType: String, bundleId: String, platform: String = "iOS")
    throws
  {
    // Check if target already exists using cache
    if cacheManager.getTarget(name) != nil {
      throw ProjectError.operationFailed("Target \(name) already exists")
    }

    // Create build configurations
    let debugConfig = XCBuildConfiguration(name: "Debug")
    debugConfig.buildSettings = [
      "BUNDLE_IDENTIFIER": .string(bundleId),
      "PRODUCT_NAME": .string("$(TARGET_NAME)"),
      "SWIFT_VERSION": .string("5.0"),
    ]

    let releaseConfig = XCBuildConfiguration(name: "Release")
    releaseConfig.buildSettings = [
      "BUNDLE_IDENTIFIER": .string(bundleId),
      "PRODUCT_NAME": .string("$(TARGET_NAME)"),
      "SWIFT_VERSION": .string("5.0"),
    ]

    pbxproj.add(object: debugConfig)
    pbxproj.add(object: releaseConfig)

    let configList = XCConfigurationList(buildConfigurations: [debugConfig, releaseConfig])
    pbxproj.add(object: configList)

    // Create target
    let target = PBXNativeTarget(
      name: name,
      buildConfigurationList: configList,
      buildPhases: [],
      buildRules: [],
      dependencies: [],
      productInstallPath: nil,
      productName: name,
      productType: PBXProductType(rawValue: productType)
    )

    // Add build phases
    let sourcesBuildPhase = PBXSourcesBuildPhase()
    let resourcesBuildPhase = PBXResourcesBuildPhase()
    let frameworksBuildPhase = PBXFrameworksBuildPhase()

    pbxproj.add(object: sourcesBuildPhase)
    pbxproj.add(object: resourcesBuildPhase)
    pbxproj.add(object: frameworksBuildPhase)

    target.buildPhases = [sourcesBuildPhase, frameworksBuildPhase, resourcesBuildPhase]

    pbxproj.add(object: target)
    pbxproj.rootObject?.targets.append(target)

    // Invalidate cache to pick up new target
    cacheManager.invalidateTarget(name)
    cacheManager.rebuildAllCaches()

    print("✅ Added target: \(name) (\(productType))")
  }

  func duplicateTarget(source: String, newName: String, newBundleId: String? = nil) throws {
    guard let sourceTarget = cacheManager.getTarget(source) else {
      throw ProjectError.targetNotFound(source)
    }

    // Check if new target already exists using cache
    if cacheManager.getTarget(newName) != nil {
      throw ProjectError.operationFailed("Target \(newName) already exists")
    }

    // Clone build configuration list
    guard let sourceConfigList = sourceTarget.buildConfigurationList else {
      throw ProjectError.operationFailed("Source target has no build configurations")
    }

    var newConfigs: [XCBuildConfiguration] = []
    for sourceConfig in sourceConfigList.buildConfigurations {
      let newConfig = XCBuildConfiguration(name: sourceConfig.name)
      newConfig.buildSettings = sourceConfig.buildSettings

      // Update bundle identifier if provided
      if let bundleId = newBundleId {
        newConfig.buildSettings["BUNDLE_IDENTIFIER"] = .string(bundleId)
      }

      pbxproj.add(object: newConfig)
      newConfigs.append(newConfig)
    }

    let newConfigList = XCConfigurationList(buildConfigurations: newConfigs)
    pbxproj.add(object: newConfigList)

    // Create new target
    let newTarget = PBXNativeTarget(
      name: newName,
      buildConfigurationList: newConfigList,
      buildPhases: [],
      buildRules: sourceTarget.buildRules,
      dependencies: [],
      productInstallPath: sourceTarget.productInstallPath,
      productName: newName,
      productType: sourceTarget.productType
    )

    // Clone build phases
    for phase in sourceTarget.buildPhases {
      if let sourcePhase = phase as? PBXSourcesBuildPhase {
        let newPhase = PBXSourcesBuildPhase()
        newPhase.files = sourcePhase.files
        pbxproj.add(object: newPhase)
        newTarget.buildPhases.append(newPhase)
      } else if let resourcePhase = phase as? PBXResourcesBuildPhase {
        let newPhase = PBXResourcesBuildPhase()
        newPhase.files = resourcePhase.files
        pbxproj.add(object: newPhase)
        newTarget.buildPhases.append(newPhase)
      } else if let frameworkPhase = phase as? PBXFrameworksBuildPhase {
        let newPhase = PBXFrameworksBuildPhase()
        newPhase.files = frameworkPhase.files
        pbxproj.add(object: newPhase)
        newTarget.buildPhases.append(newPhase)
      }
    }

    pbxproj.add(object: newTarget)
    pbxproj.rootObject?.targets.append(newTarget)

    // Invalidate cache to pick up new target
    cacheManager.invalidateTarget(newName)
    cacheManager.rebuildAllCaches()

    print("✅ Duplicated target: \(source) -> \(newName)")
  }

  func removeTarget(name: String) throws {
    guard let target = cacheManager.getTarget(name) else {
      throw ProjectError.targetNotFound(name)
    }

    // Remove from project targets
    pbxproj.rootObject?.targets.removeAll { $0 === target }

    // Remove dependencies from other targets
    for otherTarget in pbxproj.nativeTargets {
      otherTarget.dependencies.removeAll { dependency in
        dependency.target === target
      }
    }

    // Remove from project
    pbxproj.delete(object: target)

    // Invalidate cache
    cacheManager.invalidateTarget(name)

    print("✅ Removed target: \(name)")
  }

  // MARK: - Dependencies & Frameworks
  func addDependency(to targetName: String, dependsOn dependencyName: String) throws {
    guard let target = cacheManager.getTarget(targetName) else {
      throw ProjectError.targetNotFound(targetName)
    }

    guard let dependency = cacheManager.getTarget(dependencyName) else {
      throw ProjectError.targetNotFound(dependencyName)
    }

    // Check if dependency already exists
    if target.dependencies.contains(where: { $0.target === dependency }) {
      print("⚠️  Dependency already exists")
      return
    }

    let targetDependency = PBXTargetDependency(target: dependency)
    pbxproj.add(object: targetDependency)
    target.dependencies.append(targetDependency)

    print("✅ Added dependency: \(targetName) -> \(dependencyName)")
  }

  func addFramework(name: String, to targetName: String, embed: Bool = false) throws {
    guard let target = cacheManager.getTarget(targetName) else {
      throw ProjectError.targetNotFound(targetName)
    }

    // Find or create frameworks build phase
    var frameworksPhase =
      target.buildPhases.first { $0 is PBXFrameworksBuildPhase } as? PBXFrameworksBuildPhase
    if frameworksPhase == nil {
      let newFrameworksPhase = PBXFrameworksBuildPhase()
      frameworksPhase = newFrameworksPhase
      pbxproj.add(object: newFrameworksPhase)
      target.buildPhases.append(newFrameworksPhase)
    }

    guard let finalFrameworksPhase = frameworksPhase else {
      throw ProjectError.operationFailed("Failed to create or find frameworks build phase")
    }

    // Create framework reference
    let frameworkRef = PBXFileReference(
      sourceTree: .sdkRoot,
      name: "\(name).framework",
      lastKnownFileType: "wrapper.framework",
      path: "System/Library/Frameworks/\(name).framework"
    )

    pbxproj.add(object: frameworkRef)

    // Add to build phase
    let buildFile = PBXBuildFile(file: frameworkRef)
    pbxproj.add(object: buildFile)
    finalFrameworksPhase.files?.append(buildFile)

    // Handle embedding if needed
    if embed {
      // Create embed frameworks phase if needed
      var embedPhase =
        target.buildPhases.first {
          $0 is PBXCopyFilesBuildPhase
            && ($0 as? PBXCopyFilesBuildPhase)?.dstSubfolderSpec == .frameworks
        } as? PBXCopyFilesBuildPhase

      if embedPhase == nil {
        let newEmbedPhase = PBXCopyFilesBuildPhase(
          dstSubfolderSpec: .frameworks, name: "Embed Frameworks")
        embedPhase = newEmbedPhase
        pbxproj.add(object: newEmbedPhase)
        target.buildPhases.append(newEmbedPhase)
      }

      guard let finalEmbedPhase = embedPhase else {
        throw ProjectError.operationFailed("Failed to create or find embed frameworks build phase")
      }

      let embedFile = PBXBuildFile(file: frameworkRef, settings: ["ATTRIBUTES": ["CodeSignOnCopy"]])
      pbxproj.add(object: embedFile)
      finalEmbedPhase.files?.append(embedFile)
    }

    print("✅ Added framework: \(name) to \(targetName)\(embed ? " (embedded)" : "")")
  }

  // MARK: - Swift Packages
  func addSwiftPackage(url: String, requirement: String, to targetName: String? = nil) throws {
    // Validate URL format
    guard url.hasPrefix("https://") || url.hasPrefix("git@") else {
      throw ProjectError.invalidArguments("Package URL must be a valid git repository URL")
    }

    // Parse requirement (e.g., "1.0.0", "from: 1.0.0", "branch: main")
    let versionRequirement: XCRemoteSwiftPackageReference.VersionRequirement

    if requirement.hasPrefix("from:") {
      let version = requirement.replacingOccurrences(of: "from:", with: "").trimmingCharacters(
        in: .whitespaces)
      // Basic semver validation
      if !version.matches("^\\d+\\.\\d+(\\.\\d+)?$") {
        throw ProjectError.invalidArguments("Invalid version format. Expected: X.Y.Z or X.Y")
      }
      versionRequirement = .upToNextMajorVersion(version)
    } else if requirement.hasPrefix("branch:") {
      let branch = requirement.replacingOccurrences(of: "branch:", with: "").trimmingCharacters(
        in: .whitespaces)
      guard !branch.isEmpty else {
        throw ProjectError.invalidArguments("Branch name cannot be empty")
      }
      versionRequirement = .branch(branch)
    } else if requirement.hasPrefix("commit:") {
      let commit = requirement.replacingOccurrences(of: "commit:", with: "").trimmingCharacters(
        in: .whitespaces)
      guard !commit.isEmpty else {
        throw ProjectError.invalidArguments("Commit hash cannot be empty")
      }
      versionRequirement = .revision(commit)
    } else if requirement.hasPrefix("exact:") {
      let version = requirement.replacingOccurrences(of: "exact:", with: "").trimmingCharacters(
        in: .whitespaces)
      if !version.matches("^\\d+\\.\\d+(\\.\\d+)?$") {
        throw ProjectError.invalidArguments("Invalid version format. Expected: X.Y.Z or X.Y")
      }
      versionRequirement = .exact(version)
    } else {
      // Assume exact version
      if !requirement.matches("^\\d+\\.\\d+(\\.\\d+)?$") {
        throw ProjectError.invalidArguments("Invalid version format. Expected: X.Y.Z or X.Y")
      }
      versionRequirement = .exact(requirement)
    }

    // Create package reference
    let packageRef = XCRemoteSwiftPackageReference(
      repositoryURL: url,
      versionRequirement: versionRequirement
    )

    pbxproj.add(object: packageRef)

    // Add to remotePackages through public API
    pbxproj.rootObject?.remotePackages.append(packageRef)

    print("✅ Added Swift Package: \(url) (\(requirement))")

    // Add to target if specified
    if let targetName = targetName {
      guard cacheManager.getTarget(targetName) != nil else {
        throw ProjectError.targetNotFound(targetName)
      }

      // Note: Adding package products to targets requires more complex logic
      // to handle package product dependencies
      print("ℹ️  To link package products, use Xcode or specify product name")
    }
  }

  func removeSwiftPackage(url: String) throws {
    guard
      let packageRef = pbxproj.rootObject?.remotePackages.first(where: { $0.repositoryURL == url })
    else {
      throw ProjectError.operationFailed("Package not found: \(url)")
    }

    // Remove from project
    pbxproj.rootObject?.remotePackages.removeAll { $0 === packageRef }
    pbxproj.delete(object: packageRef)

    print("✅ Removed Swift Package: \(url)")
  }

  func listSwiftPackages() {
    print("📦 Swift Packages:")

    let packages = pbxproj.rootObject?.remotePackages ?? []

    if packages.isEmpty {
      print("  No packages found")
      return
    }

    for package in packages {
      print("  - \(package.repositoryURL ?? "Unknown")")
      if let requirement = package.versionRequirement {
        print("    Requirement: \(requirement)")
      }
    }
  }

  func updateSwiftPackages(force: Bool = false) throws {
    print("📦 Updating Swift Packages...")

    let packages = pbxproj.rootObject?.remotePackages ?? []

    if packages.isEmpty {
      print("  No packages found")
      return
    }

    print("  Found \(packages.count) package(s) to update:")
    var updatedCount = 0

    for package in packages {
      guard let url = package.repositoryURL else {
        print("  ⚠️  Skipping package with unknown URL")
        continue
      }

      print("  - \(url)")

      if let requirement = package.versionRequirement {
        print("    Current: \(requirement)")

        // For this initial implementation, we'll provide information about the update process
        // In a real implementation, we would need to:
        // 1. Query the repository for available versions/tags
        // 2. Compare with current constraints
        // 3. Update the versionRequirement if needed

        switch requirement {
        case .upToNextMajorVersion(let version):
          if force {
            print("    ℹ️  Force update requested - would update from 'from: \(version)' to latest")
            updatedCount += 1
          } else {
            print("    ✅ Already using flexible version constraint 'from: \(version)'")
          }

        case .upToNextMinorVersion(let version):
          if force {
            print(
              "    ℹ️  Force update requested - would update from 'upToNextMinor: \(version)' to latest"
            )
            updatedCount += 1
          } else {
            print("    ✅ Already using flexible version constraint 'upToNextMinor: \(version)'")
          }

        case .exact(let version):
          print("    ℹ️  Would update from exact version '\(version)' to latest compatible")
          if force {
            print("    ⚠️  Force update would remove version pinning")
          }
          updatedCount += 1

        case .branch(let branch):
          print("    ℹ️  Using branch '\(branch)' - would pull latest commits")
          updatedCount += 1

        case .revision(let revision):
          print("    ℹ️  Using revision '\(revision)' - would update to latest")
          updatedCount += 1

        case .range(let from, let to):
          if force {
            print(
              "    ℹ️  Force update requested - would update from range '\(from)..<\(to)' to latest")
            updatedCount += 1
          } else {
            print("    ✅ Already using range constraint '\(from)..<\(to)'")
          }
        }
      } else {
        print("    ⚠️  No version requirement specified")
      }
    }

    if updatedCount == 0 {
      print("✅ All packages are already using flexible version constraints")
      print(
        "ℹ️  Use 'swift package update' in your project directory to fetch latest compatible versions"
      )
    } else {
      print("ℹ️  Found \(updatedCount) package(s) that could benefit from updates")
      print(
        "ℹ️  Note: Actual package resolution requires running 'swift package update' in your project"
      )
      print("ℹ️  This command updates the project file constraints, not the resolved versions")

      if !force {
        print("ℹ️  Use --force to update exact version constraints to flexible ranges")
      }
    }
  }

  // MARK: - Build Phases
  func addBuildPhase(type: String, name: String, to targetName: String, script: String? = nil)
    throws
  {
    guard let target = pbxproj.nativeTargets.first(where: { $0.name == targetName }) else {
      throw ProjectError.targetNotFound(targetName)
    }

    switch type.lowercased() {
    case "run_script", "script":
      guard let script = script else {
        throw ProjectError.operationFailed("Script required for run_script phase")
      }

      // Validate script for security before adding
      guard SecurityUtils.validateShellScript(script) else {
        throw ProjectError.invalidArguments(
          "Script contains dangerous patterns and cannot be added")
      }

      let scriptPhase = PBXShellScriptBuildPhase(
        name: name,
        shellScript: escapeShellCommand(script)
      )

      pbxproj.add(object: scriptPhase)
      target.buildPhases.append(scriptPhase)

      print("✅ Added run script phase: \(name)")

    case "copy_files", "copy":
      let copyPhase = PBXCopyFilesBuildPhase(
        dstSubfolderSpec: .resources,
        name: name
      )

      pbxproj.add(object: copyPhase)
      target.buildPhases.append(copyPhase)

      print("✅ Added copy files phase: \(name)")

    default:
      throw ProjectError.operationFailed("Unknown build phase type: \(type)")
    }
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

        // Check if file already exists using cache
        if cacheManager.getFileReference(fileName) != nil {
          print("⚠️  File \(fileName) already exists, skipping")
          skippedFiles += 1
          continue
        }

        // Find parent group using cache
        guard
          let parentGroup = cacheManager.getGroup(groupPath)
            ?? findGroup(named: groupPath, in: pbxproj.groups)
        else {
          throw ProjectError.groupNotFound(groupPath)
        }

        // Create file reference
        let fileRef = PBXFileReference(
          sourceTree: .group,
          lastKnownFileType: fileType(for: path),
          path: fileName
        )

        // Add to project
        pbxproj.add(object: fileRef)
        parentGroup.children.append(fileRef)

        // Invalidate cache since we added a new file
        cacheManager.invalidateFileReference(fileName)

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

  // MARK: - Path Updates
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

  // MARK: - Group Management
  func ensureGroupHierarchy(_ path: String) -> PBXGroup? {
    return profiler?.measureOperation("ensureGroupHierarchy-\(path)") {
      return _ensureGroupHierarchy(path)
    } ?? _ensureGroupHierarchy(path)
  }

  private func _ensureGroupHierarchy(_ path: String) -> PBXGroup? {
    // Check cache first
    if let cachedGroup = cacheManager.getGroup(path) {
      return cachedGroup
    }

    let components = path.split(separator: "/").map(String.init)
    guard let mainGroup = pbxproj.rootObject?.mainGroup else {
      print("⚠️  No main group found in project")
      return nil
    }

    var currentGroup = mainGroup
    var currentPath = ""

    for component in components {
      currentPath = currentPath.isEmpty ? component : "\(currentPath)/\(component)"

      // Check cache for this path segment
      if let cachedSegment = cacheManager.getGroup(currentPath) {
        currentGroup = cachedSegment
        continue
      }

      // Look for existing child group
      if let existingGroup = currentGroup.children.compactMap({ $0 as? PBXGroup })
        .first(where: { $0.name == component || $0.path == component })
      {
        currentGroup = existingGroup
      } else {
        // Create new group
        let newGroup = PBXGroup(
          children: [],
          sourceTree: .group,
          name: component,
          path: component
        )

        pbxproj.add(object: newGroup)
        currentGroup.children.append(newGroup)
        currentGroup = newGroup

        // Invalidate cache since we created a new group
        cacheManager.invalidateGroup(currentPath)

        print("📁 Created group: \(component)")
      }
    }

    return currentGroup
  }

  // Create multiple groups at once
  func createGroups(_ groupPaths: [String]) {
    for groupPath in groupPaths {
      _ = ensureGroupHierarchy(groupPath)
    }
  }

  // Enhanced group finding that supports nested paths
  func findGroupAtPath(_ path: String) -> PBXGroup? {
    guard let mainGroup = pbxproj.rootObject?.mainGroup else { return nil }

    if path.isEmpty {
      return mainGroup
    }

    return findGroupByPath(path, in: pbxproj.groups, rootGroup: mainGroup)
  }

  // MARK: - Build Settings & Configuration
  func updateBuildSettings(targets: [String], update: (inout BuildSettings) -> Void) {
    for targetName in targets {
      guard let target = cacheManager.getTarget(targetName),
        let configList = target.buildConfigurationList
      else {
        print("⚠️  Target '\(targetName)' not found")
        continue
      }

      for config in configList.buildConfigurations {
        update(&config.buildSettings)
        print("⚙️  Updated build settings for \(targetName) - \(config.name)")
      }
    }
  }

  func setBuildSetting(key: String, value: String, targets: [String], configuration: String? = nil)
  {
    for targetName in targets {
      guard let target = cacheManager.getTarget(targetName),
        let configList = target.buildConfigurationList
      else {
        print("⚠️  Target '\(targetName)' not found")
        continue
      }

      for config in configList.buildConfigurations {
        if let filterConfig = configuration, config.name != filterConfig {
          continue
        }
        config.buildSettings[key] = .string(value)
        print("⚙️  Set \(key) = \(value) for \(targetName) - \(config.name)")
      }
    }
  }

  func getBuildSettings(for targetName: String, configuration: String? = nil) -> [String: [String:
    Any]]
  {
    guard let target = cacheManager.getTarget(targetName),
      let configList = target.buildConfigurationList
    else {
      print("⚠️  Target '\(targetName)' not found")
      return [:]
    }

    var result: [String: [String: Any]] = [:]

    for config in configList.buildConfigurations {
      if let filterConfig = configuration, config.name != filterConfig {
        continue
      }
      result[config.name] = config.buildSettings
    }

    return result
  }

  func listBuildConfigurations(for targetName: String? = nil) {
    if let targetName = targetName {
      guard let target = cacheManager.getTarget(targetName) else {
        print("⚠️  Target '\(targetName)' not found")
        return
      }

      print("🔧 Build configurations for \(targetName):")
      if let configList = target.buildConfigurationList {
        for config in configList.buildConfigurations {
          print("  - \(config.name)")
        }
      }
    } else {
      // List all project configurations
      print("🔧 Project build configurations:")
      if let configList = pbxproj.rootObject?.buildConfigurationList {
        for config in configList.buildConfigurations {
          print("  - \(config.name)")
        }
      }
    }
  }

  // Enhanced list-build-settings command - Xcode-style output
  func listBuildSettings(
    targetName: String? = nil, configuration: String? = nil, showInherited: Bool = false,
    outputJSON: Bool = false, showAll: Bool = false
  ) {
    if outputJSON {
      outputJSONBuildSettings(
        targetName: targetName, configuration: configuration,
        showInherited: showInherited, showAll: showAll
      )
      return
    }

    outputConsoleBuildSettings(
      targetName: targetName, configuration: configuration,
      showInherited: showInherited, showAll: showAll
    )
  }

  // MARK: - Build Settings Data Collection

  /// Collects project-level build settings data
  private func collectProjectBuildSettings(
    configuration: String? = nil
  ) -> (settingsData: [String: [String: Any]], allKeys: Set<String>, activeConfigs: [String]) {
    guard let configList = pbxproj.rootObject?.buildConfigurationList else {
      return ([:], [], [])
    }

    let configs = configList.buildConfigurations
    let configNames = configs.map { $0.name }

    var allSettingKeys = Set<String>()
    var settingsData: [String: [String: Any]] = [:]

    for config in configs {
      if let filterConfig = configuration, config.name != filterConfig {
        continue
      }

      settingsData[config.name] = config.buildSettings
      allSettingKeys.formUnion(config.buildSettings.keys)
    }

    let activeConfigs = configuration.map { [$0] } ?? configNames
    return (settingsData, allSettingKeys, activeConfigs)
  }

  /// Collects target-level build settings data with inheritance info
  private func collectTargetBuildSettings(
    target: PBXNativeTarget, configuration: String? = nil, showInherited: Bool = false
  ) -> (
    settingsData: [String: [String: Any]],
    projectSettingsData: [String: [String: Any]],
    allKeys: Set<String>,
    activeConfigs: [String]
  ) {
    guard let targetConfigList = target.buildConfigurationList else {
      return ([:], [:], [], [])
    }

    let configs = targetConfigList.buildConfigurations
    let configNames = configs.map { $0.name }
    let projectConfigList = pbxproj.rootObject?.buildConfigurationList

    var allSettingKeys = Set<String>()
    var settingsData: [String: [String: Any]] = [:]
    var projectSettingsData: [String: [String: Any]] = [:]

    for config in configs {
      if let filterConfig = configuration, config.name != filterConfig {
        continue
      }

      settingsData[config.name] = config.buildSettings
      allSettingKeys.formUnion(config.buildSettings.keys)

      // Get project settings for this config
      if let projectConfig = projectConfigList?.buildConfigurations.first(where: {
        $0.name == config.name
      }) {
        projectSettingsData[config.name] = projectConfig.buildSettings
        if showInherited {
          allSettingKeys.formUnion(projectConfig.buildSettings.keys)
        }
      }
    }

    let activeConfigs = configuration.map { [$0] } ?? configNames
    return (settingsData, projectSettingsData, allSettingKeys, activeConfigs)
  }

  // MARK: - Build Settings Output Formatting

  /// Formats and displays project build settings to console
  private func formatProjectBuildSettingsOutput(
    settingsData: [String: [String: Any]], allKeys: Set<String>, activeConfigs: [String]
  ) {
    if allKeys.isEmpty {
      print("  (No explicit settings defined)")
      return
    }

    let sortedKeys = allKeys.sorted()

    for key in sortedKeys {
      var values: [String: String] = [:]

      for configName in activeConfigs {
        if let value = settingsData[configName]?[key] {
          values[configName] = formatBuildSettingValue(value)
        }
      }

      let uniqueValues = Set(values.values)

      if uniqueValues.count == 1, let singleValue = values.values.first {
        print("  \(key): \(singleValue)")
      } else {
        print("  \(key)")
        for configName in activeConfigs.sorted() {
          if let value = values[configName] {
            print("    \(configName): \(value)")
          }
        }
      }
    }
  }

  /// Formats and displays target build settings to console
  private func formatTargetBuildSettingsOutput(
    settingsData: [String: [String: Any]],
    projectSettingsData: [String: [String: Any]],
    allKeys: Set<String>,
    activeConfigs: [String],
    showInherited: Bool
  ) {
    if allKeys.isEmpty && !showInherited {
      print("  (No explicit settings defined at target level)")
      return
    }

    let sortedKeys = allKeys.sorted()

    for key in sortedKeys {
      let (values, inheritedValues, hasTargetSetting, isInheritedOnly) = collectSettingValues(
        key: key,
        activeConfigs: activeConfigs,
        settingsData: settingsData,
        projectSettingsData: projectSettingsData,
        showInherited: showInherited
      )

      if !hasTargetSetting && !showInherited {
        continue
      }

      displaySettingValues(
        key: key,
        values: values,
        inheritedValues: inheritedValues,
        isInheritedOnly: isInheritedOnly,
        activeConfigs: activeConfigs,
        settingsData: settingsData,
        showInherited: showInherited
      )
    }
  }

  // MARK: - Build Settings Output Coordination

  /// Handles JSON output for build settings
  private func outputJSONBuildSettings(
    targetName: String? = nil, configuration: String? = nil,
    showInherited: Bool = false, showAll: Bool = false
  ) {
    listBuildSettingsJSON(
      targetName: targetName, configuration: configuration,
      showInherited: showInherited, showAll: showAll
    )
  }

  /// Handles console output for build settings
  private func outputConsoleBuildSettings(
    targetName: String? = nil, configuration: String? = nil,
    showInherited: Bool = false, showAll: Bool = false
  ) {
    if showAll {
      listAllBuildSettings(configuration: configuration, showInherited: showInherited)
      return
    }

    if let targetName = targetName {
      outputTargetBuildSettings(
        targetName: targetName, configuration: configuration, showInherited: showInherited
      )
    } else {
      outputProjectBuildSettings(configuration: configuration)
    }
  }

  /// Outputs build settings for a specific target
  private func outputTargetBuildSettings(
    targetName: String, configuration: String? = nil, showInherited: Bool = false
  ) {
    guard let target = cacheManager.getTarget(targetName) else {
      print("⚠️  Target '\(targetName)' not found")
      print("Available targets: \(pbxproj.nativeTargets.map { $0.name }.joined(separator: ", "))")
      exit(1)
    }

    print("🎯 Build Settings for Target: \(targetName)")
    print("─" + String(repeating: "─", count: 80))
    print("")

    let (settingsData, projectSettingsData, allKeys, activeConfigs) = collectTargetBuildSettings(
      target: target, configuration: configuration, showInherited: showInherited
    )

    formatTargetBuildSettingsOutput(
      settingsData: settingsData,
      projectSettingsData: projectSettingsData,
      allKeys: allKeys,
      activeConfigs: activeConfigs,
      showInherited: showInherited
    )

    print("")
  }

  /// Outputs build settings for the project
  private func outputProjectBuildSettings(configuration: String? = nil) {
    guard pbxproj.rootObject?.buildConfigurationList != nil else {
      print("⚠️  No project build configuration found")
      exit(1)
    }

    let projectName = pbxproj.rootObject?.name ?? projectPath.lastComponentWithoutExtension
    print("🏗️  Build Settings for Project: \(projectName)")
    print("─" + String(repeating: "─", count: 80))
    print("")

    let (settingsData, allKeys, activeConfigs) = collectProjectBuildSettings(
      configuration: configuration)

    formatProjectBuildSettingsOutput(
      settingsData: settingsData, allKeys: allKeys, activeConfigs: activeConfigs
    )

    print("")
  }

  private func formatBuildSettingValue(_ value: Any) -> String {
    if let stringValue = value as? String {
      return stringValue
    } else if let arrayValue = value as? [String] {
      return arrayValue.joined(separator: ", ")
    } else {
      return "\(value)"
    }
  }

  // Common helper to display a setting with its values across configurations
  private func displaySettingValues(
    key: String,
    values: [String: String],
    inheritedValues: [String: String],
    isInheritedOnly: Bool,
    activeConfigs: [String],
    settingsData: [String: [String: Any]],
    showInherited: Bool
  ) {
    // Check if all configs have the same value
    let uniqueValues = Set(values.values)

    if uniqueValues.count == 1, let singleValue = values.values.first {
      // Same value across all configurations - display inline
      if isInheritedOnly {
        print("  \(key): \(singleValue) [inherited from project]")
      } else {
        print("  \(key): \(singleValue)")
        // Show if it overrides a project setting
        let uniqueInheritedValues = Set(inheritedValues.values)
        if uniqueInheritedValues.count == 1, let projectValue = inheritedValues.values.first,
          projectValue != singleValue
        {
          print("    ↳ overrides project: \(projectValue)")
        }
      }
    } else {
      // Different values per configuration - show on separate lines
      print("  \(key)")
      for configName in activeConfigs.sorted() {
        if let value = values[configName] {
          let isInherited = settingsData[configName]?[key] == nil && showInherited
          let inheritedSuffix = isInherited ? " [inherited]" : ""
          print("    \(configName): \(value)\(inheritedSuffix)")

          // Show override info if applicable
          if !isInherited, let projectValue = inheritedValues[configName], projectValue != value {
            print("      ↳ overrides project: \(projectValue)")
          }
        }
      }
    }
  }

  // Helper to collect setting values across configurations
  private func collectSettingValues(
    key: String,
    activeConfigs: [String],
    settingsData: [String: [String: Any]],
    projectSettingsData: [String: [String: Any]],
    showInherited: Bool
  ) -> (
    values: [String: String], inheritedValues: [String: String], hasTargetSetting: Bool,
    isInheritedOnly: Bool
  ) {
    var hasTargetSetting = false
    var isInheritedOnly = true
    var values: [String: String] = [:]
    var inheritedValues: [String: String] = [:]

    for configName in activeConfigs {
      if let targetValue = settingsData[configName]?[key] {
        hasTargetSetting = true
        isInheritedOnly = false
        values[configName] = formatBuildSettingValue(targetValue)
      } else if showInherited, let projectValue = projectSettingsData[configName]?[key] {
        values[configName] = formatBuildSettingValue(projectValue)
        inheritedValues[configName] = formatBuildSettingValue(projectValue)
      }

      // Track project values for override detection
      if let projectValue = projectSettingsData[configName]?[key] {
        let projectValueStr = formatBuildSettingValue(projectValue)
        if inheritedValues[configName] == nil && values[configName] != projectValueStr {
          inheritedValues[configName] = projectValueStr
        }
      }
    }

    return (values, inheritedValues, hasTargetSetting, isInheritedOnly)
  }

  // JSON output for list-build-settings
  private func listBuildSettingsJSON(
    targetName: String? = nil, configuration: String? = nil,
    showInherited: Bool = false, showAll: Bool = false
  ) {
    var result: [String: Any] = [:]

    if showAll {
      // Include project and all targets
      var allSettings: [String: Any] = [:]

      // Project settings
      if let configList = pbxproj.rootObject?.buildConfigurationList {
        allSettings["project"] = collectBuildSettingsData(
          configList: configList,
          configuration: configuration
        )
      }

      // All targets
      var targetsSettings: [String: Any] = [:]
      for target in pbxproj.nativeTargets {
        if target.buildConfigurationList != nil {
          let targetData = collectTargetBuildSettingsData(
            target: target,
            configuration: configuration,
            showInherited: showInherited
          )
          targetsSettings[target.name] = targetData
        }
      }
      allSettings["targets"] = targetsSettings
      result = allSettings

    } else if let targetName = targetName {
      // Specific target
      guard let target = cacheManager.getTarget(targetName) else {
        let errorDict =
          [
            "error": "Target '\(targetName)' not found",
            "availableTargets": pbxproj.nativeTargets.map { $0.name },
          ] as [String: Any]
        if let jsonData = try? JSONSerialization.data(
          withJSONObject: errorDict, options: .prettyPrinted),
          let jsonString = String(data: jsonData, encoding: .utf8)
        {
          print(jsonString)
        } else {
          print("{\"error\": \"Target '\(targetName)' not found\"}")
        }
        exit(1)
      }

      result = collectTargetBuildSettingsData(
        target: target,
        configuration: configuration,
        showInherited: showInherited
      )

    } else {
      // Project only
      if let configList = pbxproj.rootObject?.buildConfigurationList {
        result = collectBuildSettingsData(
          configList: configList,
          configuration: configuration
        )
      }
    }

    // Output JSON
    if let jsonData = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted),
      let jsonString = String(data: jsonData, encoding: .utf8)
    {
      print(jsonString)
    } else {
      print("{}")
    }
  }

  // Helper to collect build settings data for JSON output (setting-centric)
  private func collectBuildSettingsData(
    configList: XCConfigurationList, configuration: String? = nil
  ) -> [String: Any] {
    var result: [String: Any] = [:]

    // Collect all settings across configurations
    var allSettingKeys = Set<String>()
    var settingsData: [String: [String: Any]] = [:]  // [ConfigName: [SettingKey: Value]]

    for config in configList.buildConfigurations {
      if let filterConfig = configuration, config.name != filterConfig {
        continue
      }

      settingsData[config.name] = config.buildSettings
      allSettingKeys.formUnion(config.buildSettings.keys)
    }

    // Build setting-centric structure
    for key in allSettingKeys {
      var values: [String: Any] = [:]

      for (configName, configSettings) in settingsData {
        if let value = configSettings[key] {
          values[configName] = formatBuildSettingValueForJSON(value)
        }
      }

      // If all configs have the same value, simplify to just the value
      let uniqueValues = Set(values.values.compactMap { "\($0)" })
      if uniqueValues.count == 1, let singleValue = values.values.first {
        result[key] = singleValue
      } else {
        result[key] = values
      }
    }

    return result
  }

  // Helper to collect target build settings with inheritance info (setting-centric)
  private func collectTargetBuildSettingsData(
    target: PBXNativeTarget, configuration: String? = nil, showInherited: Bool = false
  ) -> [String: Any] {
    guard let targetConfigList = target.buildConfigurationList else {
      return [:]
    }

    var result: [String: Any] = [:]
    let projectConfigList = pbxproj.rootObject?.buildConfigurationList

    // Collect all settings across configurations
    var allSettingKeys = Set<String>()
    var targetSettingsData: [String: [String: Any]] = [:]  // [ConfigName: [SettingKey: Value]]
    var projectSettingsData: [String: [String: Any]] = [:]  // For inheritance tracking

    for config in targetConfigList.buildConfigurations {
      if let filterConfig = configuration, config.name != filterConfig {
        continue
      }

      targetSettingsData[config.name] = config.buildSettings
      allSettingKeys.formUnion(config.buildSettings.keys)

      // Get project settings for this config if showing inherited
      if showInherited {
        if let projectConfig = projectConfigList?.buildConfigurations.first(where: {
          $0.name == config.name
        }) {
          projectSettingsData[config.name] = projectConfig.buildSettings
          allSettingKeys.formUnion(projectConfig.buildSettings.keys)
        }
      }
    }

    // Build setting-centric structure
    for key in allSettingKeys {
      var values: [String: Any] = [:]
      var sources: [String: String] = [:]  // Track source of each value
      var hasTargetSetting = false

      for configName in targetSettingsData.keys {
        if let targetValue = targetSettingsData[configName]?[key] {
          values[configName] = formatBuildSettingValueForJSON(targetValue)
          sources[configName] = "target"
          hasTargetSetting = true
        } else if showInherited, let projectValue = projectSettingsData[configName]?[key] {
          values[configName] = formatBuildSettingValueForJSON(projectValue)
          sources[configName] = "project"
        }
      }

      // Skip inherited-only settings if not showing inherited
      if !hasTargetSetting && !showInherited {
        continue
      }

      // If all configs have the same value and source, simplify
      let uniqueValues = Set(values.values.compactMap { "\($0)" })
      let uniqueSources = Set(sources.values)

      if uniqueValues.count == 1, let singleValue = values.values.first {
        // All configs have same value
        if showInherited && uniqueSources.count == 1, let source = sources.values.first {
          // Include source info if showing inherited
          result[key] = [
            "value": singleValue,
            "source": source,
          ]
        } else {
          // Just the value if not showing inherited or all from target
          result[key] = singleValue
        }
      } else {
        // Different values per config
        if showInherited {
          // Include source info for each config
          var configData: [String: Any] = [:]
          for (configName, value) in values {
            configData[configName] = [
              "value": value,
              "source": sources[configName] ?? "unknown",
            ]
          }
          result[key] = configData
        } else {
          // Just values without source
          result[key] = values
        }
      }
    }

    return result
  }

  // Format value for JSON output
  private func formatBuildSettingValueForJSON(_ value: Any) -> Any {
    if let arrayValue = value as? [String] {
      return arrayValue
    }
    return formatBuildSettingValue(value)
  }

  // List all build settings (project + all targets)
  private func listAllBuildSettings(configuration: String? = nil, showInherited: Bool = false) {
    // Display settings directly for project
    let projectName = pbxproj.rootObject?.name ?? projectPath.lastComponentWithoutExtension
    print("🏗️  Build Settings for Project: \(projectName)")
    print("─" + String(repeating: "─", count: 80))
    print("")

    displayProjectBuildSettings(configuration: configuration)

    // All targets
    for target in pbxproj.nativeTargets {
      print("")
      print("🎯 Build Settings for Target: \(target.name)")
      print("─" + String(repeating: "─", count: 80))
      print("")

      displayTargetBuildSettings(
        target: target,
        configuration: configuration,
        showInherited: showInherited
      )
    }
  }

  // Helper to display project settings without header
  private func displayProjectBuildSettings(configuration: String? = nil) {
    guard let configList = pbxproj.rootObject?.buildConfigurationList else {
      print("  (No project build configuration found)")
      return
    }

    // Get all configurations
    let configs = configList.buildConfigurations
    let configNames = configs.map { $0.name }

    // Collect all unique setting keys across all configurations
    var allSettingKeys = Set<String>()
    var settingsData: [String: [String: Any]] = [:]

    for config in configs {
      if let filterConfig = configuration, config.name != filterConfig {
        continue
      }

      settingsData[config.name] = config.buildSettings
      allSettingKeys.formUnion(config.buildSettings.keys)
    }

    // Filter configs if specific configuration requested
    let activeConfigs = configuration.map { [$0] } ?? configNames

    if allSettingKeys.isEmpty {
      print("  (No explicit settings defined)")
      return
    }

    // Sort settings alphabetically
    let sortedKeys = allSettingKeys.sorted()

    // Display each setting with its values across configurations
    for key in sortedKeys {
      var values: [String: String] = [:]

      for configName in activeConfigs {
        if let value = settingsData[configName]?[key] {
          values[configName] = formatBuildSettingValue(value)
        }
      }

      // Check if all configs have the same value
      let uniqueValues = Set(values.values)

      if uniqueValues.count == 1, let singleValue = values.values.first {
        // Same value across all configurations - display inline
        print("  \(key): \(singleValue)")
      } else {
        // Different values per configuration - show on separate lines
        print("  \(key)")
        for configName in activeConfigs.sorted() {
          if let value = values[configName] {
            print("    \(configName): \(value)")
          }
        }
      }
    }
  }

  // Helper to display target settings without header
  private func displayTargetBuildSettings(
    target: PBXNativeTarget, configuration: String? = nil, showInherited: Bool = false
  ) {
    guard let targetConfigList = target.buildConfigurationList else {
      print("  (No build configuration found)")
      return
    }

    // Get all configurations
    let configs = targetConfigList.buildConfigurations
    let configNames = configs.map { $0.name }

    // Get project-level settings for comparison
    let projectConfigList = pbxproj.rootObject?.buildConfigurationList

    // Collect all unique setting keys across all configurations
    var allSettingKeys = Set<String>()
    var settingsData: [String: [String: Any]] = [:]
    var projectSettingsData: [String: [String: Any]] = [:]

    for config in configs {
      if let filterConfig = configuration, config.name != filterConfig {
        continue
      }

      settingsData[config.name] = config.buildSettings
      allSettingKeys.formUnion(config.buildSettings.keys)

      // Get project settings for this config
      if let projectConfig = projectConfigList?.buildConfigurations.first(where: {
        $0.name == config.name
      }) {
        projectSettingsData[config.name] = projectConfig.buildSettings
        if showInherited {
          allSettingKeys.formUnion(projectConfig.buildSettings.keys)
        }
      }
    }

    // Filter configs if specific configuration requested
    let activeConfigs: [String]
    if let config = configuration {
      activeConfigs = [config]
    } else {
      activeConfigs = configNames
    }

    if allSettingKeys.isEmpty && !showInherited {
      print("  (No explicit settings defined at target level)")
      return
    }

    // Sort settings alphabetically
    let sortedKeys = allSettingKeys.sorted()

    // Display each setting with its values across configurations
    for key in sortedKeys {
      let (values, inheritedValues, hasTargetSetting, isInheritedOnly) = collectSettingValues(
        key: key,
        activeConfigs: activeConfigs,
        settingsData: settingsData,
        projectSettingsData: projectSettingsData,
        showInherited: showInherited
      )

      if !hasTargetSetting && !showInherited {
        continue  // Skip inherited-only settings if not showing inherited
      }

      displaySettingValues(
        key: key,
        values: values,
        inheritedValues: inheritedValues,
        isInheritedOnly: isInheritedOnly,
        activeConfigs: activeConfigs,
        settingsData: settingsData,
        showInherited: showInherited
      )
    }
  }

  // MARK: - Validation
  func validate() -> [String] {
    var issues: [String] = []

    // Check for orphaned file references
    for fileRef in pbxproj.fileReferences {
      var found = false
      for group in pbxproj.groups {
        if group.children.contains(where: { $0 === fileRef }) {
          found = true
          break
        }
      }
      if !found {
        issues.append("Orphaned file reference: \(fileRef.path ?? fileRef.name ?? "unknown")")
      }
    }

    // Check for missing build files
    for target in pbxproj.nativeTargets {
      guard let sourcePhase = sourceBuildPhase(for: target) else { continue }
      for buildFileRef in sourcePhase.files ?? [] {
        if buildFileRef.file == nil {
          issues.append("Missing file reference in target: \(target.name)")
        }
      }
    }

    return issues
  }

  func listInvalidReferences() {
    print("🔍 Checking for invalid file and folder references...")

    var invalidRefs: [(group: String, path: String, issue: String)] = []
    let pathResolver = PathResolver(pbxproj: pbxproj, projectDir: projectPath.parent())

    // Check each file reference
    func checkFilesInGroup(_ group: PBXGroup, groupPath: String) {
      // First check if the group itself represents a folder that should exist
      if let issue = pathResolver.validateGroup(group) {
        let displayPath = group.path ?? group.name ?? "unknown"
        invalidRefs.append(
          (
            group: groupPath.isEmpty ? "Root" : groupPath,
            path: displayPath,
            issue: issue
          ))
      }

      // Then check children
      for child in group.children {
        if let fileRef = child as? PBXFileReference {
          if let issue = pathResolver.validateFileReference(fileRef, in: group) {
            let displayPath = fileRef.path ?? fileRef.name ?? "unknown"
            invalidRefs.append(
              (
                group: groupPath,
                path: displayPath,
                issue: issue
              ))
          }
        } else if let subgroup = child as? PBXGroup {
          let subgroupName = subgroup.name ?? subgroup.path ?? "unnamed"
          let newPath = groupPath.isEmpty ? subgroupName : "\(groupPath)/\(subgroupName)"
          checkFilesInGroup(subgroup, groupPath: newPath)
        }
      }
    }

    // Start checking from root group
    if let rootGroup = pbxproj.rootObject?.mainGroup {
      checkFilesInGroup(rootGroup, groupPath: "")
    }

    // Report results
    if invalidRefs.isEmpty {
      print("✅ All file references are valid")
    } else {
      print("❌ Found \(invalidRefs.count) invalid file reference(s):\n")
      for ref in invalidRefs {
        print("  Group: \(ref.group.isEmpty ? "Root" : ref.group)")
        print("  File:  \(ref.path)")
        print("  Issue: \(ref.issue)")
        print("")
      }
    }
  }

  func removeInvalidReferences() {
    print("🔍 Checking for invalid file and folder references to remove...")

    var removedCount = 0
    let pathResolver = PathResolver(pbxproj: pbxproj, projectDir: projectPath.parent())

    // Collect invalid references to remove
    var refsToRemove: [PBXFileReference] = []
    var groupsToRemove: [PBXGroup] = []

    func findInvalidFilesInGroup(_ group: PBXGroup) {
      // First check if the group itself represents a folder that should exist
      if pathResolver.validateGroup(group) != nil {
        groupsToRemove.append(group)
        let displayPath = group.path ?? group.name ?? "unknown"
        print("  ❌ Will remove folder: \(displayPath)")
      }

      // Then check children
      for child in group.children {
        if let fileRef = child as? PBXFileReference {
          if pathResolver.validateFileReference(fileRef, in: group) != nil {
            refsToRemove.append(fileRef)
            let displayPath = fileRef.path ?? fileRef.name ?? "unknown"
            print("  ❌ Will remove: \(displayPath)")
          }
        } else if let subgroup = child as? PBXGroup {
          findInvalidFilesInGroup(subgroup)
        }
      }
    }

    // Start checking from root group
    if let rootGroup = pbxproj.rootObject?.mainGroup {
      findInvalidFilesInGroup(rootGroup)
    }

    // Remove invalid groups
    for groupToRemove in groupsToRemove {
      // Remove from parent groups
      for group in pbxproj.groups {
        group.children.removeAll { $0 === groupToRemove }
      }
      removedCount += 1
    }

    // Remove invalid file references
    for fileRef in refsToRemove {
      // Remove from all groups
      for group in pbxproj.groups {
        group.children.removeAll { $0 === fileRef }
      }

      // Remove from all build phases
      buildPhaseManager.removeBuildFiles(for: fileRef)

      // Remove build files that reference this file
      let buildFilesToRemove = pbxproj.buildFiles.filter { $0.file === fileRef }
      for buildFile in buildFilesToRemove {
        pbxproj.delete(object: buildFile)
      }

      // Remove from project
      pbxproj.delete(object: fileRef)
      removedCount += 1
    }

    // Report results
    if removedCount == 0 {
      print("✅ No invalid references to remove")
    } else {
      print("✅ Removed \(removedCount) invalid file reference(s)")
    }
  }

  // MARK: - Tree Display
  func listProjectTree() {
    if let rootGroup = pbxproj.rootObject?.mainGroup {
      let projectName = pbxproj.rootObject?.name ?? projectPath.lastComponentWithoutExtension
      print(projectName)

      // Process root group's children directly
      let children = rootGroup.children
      for (index, child) in children.enumerated() {
        let childIsLast = (index == children.count - 1)
        printTreeNode(child, prefix: "", isLast: childIsLast, parentPath: "")
      }
    } else {
      print("❌ No project structure found")
    }
  }

  func listTargetTree(targetName: String) throws {
    guard let target = pbxproj.nativeTargets.first(where: { $0.name == targetName }) else {
      throw ProjectError.targetNotFound(targetName)
    }

    print("📁 Files in target '\(targetName)':")

    // Collect all files from target's build phases
    var fileReferences: Set<PBXFileReference> = []
    var fileToGroup: [PBXFileReference: PBXGroup] = [:]

    // Collect files from all build phases
    for buildPhase in target.buildPhases {
      var phaseFiles: [PBXBuildFile] = []

      switch buildPhase {
      case let sourcesBuildPhase as PBXSourcesBuildPhase:
        phaseFiles = sourcesBuildPhase.files ?? []
      case let resourcesBuildPhase as PBXResourcesBuildPhase:
        phaseFiles = resourcesBuildPhase.files ?? []
      case let frameworksBuildPhase as PBXFrameworksBuildPhase:
        phaseFiles = frameworksBuildPhase.files ?? []
      case let copyFilesBuildPhase as PBXCopyFilesBuildPhase:
        phaseFiles = copyFilesBuildPhase.files ?? []
      default:
        continue
      }

      for buildFile in phaseFiles {
        if let fileRef = buildFile.file as? PBXFileReference {
          fileReferences.insert(fileRef)
        }
      }
    }

    // Find parent groups for files
    if let rootGroup = pbxproj.rootObject?.mainGroup {
      findParentGroups(for: Array(fileReferences), in: rootGroup, parentGroups: &fileToGroup)
    }

    // Build tree structure
    var tree: [String: [PBXFileReference]] = [:]
    for fileRef in fileReferences {
      let groupPath = buildGroupPath(for: fileRef, fileToGroup: fileToGroup)
      if tree[groupPath] == nil {
        tree[groupPath] = []
      }
      tree[groupPath]?.append(fileRef)
    }

    // Display tree
    let sortedPaths = tree.keys.sorted()
    for path in sortedPaths {
      if !path.isEmpty {
        print("📁 \(path)")
      }
      if let files = tree[path] {
        let sortedFiles = files.sorted {
          ($0.path ?? $0.name ?? "") < ($1.path ?? $1.name ?? "")
        }
        for file in sortedFiles {
          let prefix = path.isEmpty ? "" : "  "
          print("\(prefix)  - \(file.path ?? file.name ?? "unknown")")
        }
      }
    }

    if fileReferences.isEmpty {
      print("  (no files)")
    } else {
      print("\nTotal: \(fileReferences.count) file(s)")
    }
  }

  private func findParentGroups(
    for files: [PBXFileReference], in group: PBXGroup,
    parentGroups: inout [PBXFileReference: PBXGroup], currentPath: String = ""
  ) {
    let groupPath = currentPath.isEmpty ? (group.name ?? group.path ?? "") : currentPath

    for child in group.children {
      if let fileRef = child as? PBXFileReference, files.contains(fileRef) {
        parentGroups[fileRef] = group
      } else if let subgroup = child as? PBXGroup {
        let subPath =
          groupPath.isEmpty
          ? (subgroup.name ?? subgroup.path ?? "")
          : "\(groupPath)/\(subgroup.name ?? subgroup.path ?? "")"
        findParentGroups(
          for: files, in: subgroup, parentGroups: &parentGroups, currentPath: subPath)
      }
    }
  }

  private func buildGroupPath(for file: PBXFileReference, fileToGroup: [PBXFileReference: PBXGroup])
    -> String
  {
    var path: [String] = []
    var currentGroup = fileToGroup[file]

    while let group = currentGroup {
      if let name = group.name ?? group.path {
        path.insert(name, at: 0)
      }
      // Find parent group
      currentGroup = nil
      for potentialParent in pbxproj.groups {
        if potentialParent.children.contains(where: { $0 === group }) {
          currentGroup = potentialParent
          break
        }
      }
      // Don't include the root group
      if currentGroup === pbxproj.rootObject?.mainGroup {
        break
      }
    }

    return path.joined(separator: "/")
  }

  func listGroupsTree() {
    if let rootGroup = pbxproj.rootObject?.mainGroup {
      let projectName = pbxproj.rootObject?.name ?? projectPath.lastComponentWithoutExtension
      print(projectName)

      // Process root group's children directly, showing only groups
      let children = rootGroup.children
      let groupChildren = children.filter {
        $0 is PBXGroup || $0 is PBXFileSystemSynchronizedRootGroup
      }

      for (index, child) in groupChildren.enumerated() {
        let childIsLast = (index == groupChildren.count - 1)
        printGroupsOnly(child, prefix: "", isLast: childIsLast)
      }
    } else {
      print("❌ No project structure found")
    }
  }

  private func printGroupsOnly(_ element: PBXFileElement, prefix: String, isLast: Bool) {
    let connector = isLast ? "└── " : "├── "
    let continuation = isLast ? "    " : "│   "

    // Only process groups
    if let group = element as? PBXGroup {
      let name = group.name ?? group.path ?? "unknown"
      print("\(prefix)\(connector)\(name)")

      // Filter children to show only groups
      let groupChildren = group.children.filter {
        $0 is PBXGroup || $0 is PBXFileSystemSynchronizedRootGroup
      }

      for (index, child) in groupChildren.enumerated() {
        let childIsLast = (index == groupChildren.count - 1)
        printGroupsOnly(child, prefix: prefix + continuation, isLast: childIsLast)
      }
    } else if let syncGroup = element as? PBXFileSystemSynchronizedRootGroup {
      let name = syncGroup.name ?? syncGroup.path ?? "unknown"
      print("\(prefix)\(connector)\(name) [synchronized]")
    }
  }

  private func printTreeNode(
    _ element: PBXFileElement, prefix: String, isLast: Bool, parentPath: String
  ) {
    let connector = isLast ? "└── " : "├── "
    let continuation = isLast ? "    " : "│   "

    // Get display name
    let name = element.name ?? element.path ?? "unknown"

    // Determine if this is an actual file/folder reference or a virtual group
    let isFileReference = element is PBXFileReference
    let isSyncFolder = element is PBXFileSystemSynchronizedRootGroup

    // For actual file/folder references, show the path
    if isFileReference {
      if let fileRef = element as? PBXFileReference {
        // Build the full path for file references
        let elementPath = fileRef.path ?? fileRef.name ?? ""
        let fullPath: String
        if parentPath.isEmpty {
          fullPath = elementPath
        } else if elementPath.isEmpty {
          fullPath = parentPath
        } else {
          fullPath = "\(parentPath)/\(elementPath)"
        }

        // Check if it's a folder reference (blue folder in Xcode)
        let isFolderRef =
          fileRef.lastKnownFileType == "folder"
          || fileRef.lastKnownFileType == "folder.assetcatalog"
          || fileRef.lastKnownFileType == "wrapper.framework"

        if isFolderRef {
          print("\(prefix)\(connector)\(name) (\(fullPath)) [folder reference]")
        } else {
          print("\(prefix)\(connector)\(name) (\(fullPath))")
        }
      }
    } else if isSyncFolder {
      // Synchronized folders (Xcode 16+)
      if let syncGroup = element as? PBXFileSystemSynchronizedRootGroup {
        let elementPath = syncGroup.path ?? syncGroup.name ?? ""
        let fullPath: String
        if parentPath.isEmpty {
          fullPath = elementPath
        } else if elementPath.isEmpty {
          fullPath = parentPath
        } else {
          fullPath = "\(parentPath)/\(elementPath)"
        }
        print("\(prefix)\(connector)\(name) (\(fullPath)) [synchronized]")
      }
    } else {
      // Virtual groups - just show the name without path
      print("\(prefix)\(connector)\(name)")
    }

    // Build path for children (considering virtual groups)
    let childPath: String
    if let group = element as? PBXGroup {
      // For virtual groups, keep the parent path
      // For groups with a path, append it
      if let groupPath = group.path, !groupPath.isEmpty {
        childPath = parentPath.isEmpty ? groupPath : "\(parentPath)/\(groupPath)"
      } else {
        childPath = parentPath
      }
    } else if isFileReference {
      // File references don't have children, but just in case
      let elementPath = element.path ?? element.name ?? ""
      childPath = parentPath.isEmpty ? elementPath : "\(parentPath)/\(elementPath)"
    } else {
      childPath = parentPath
    }

    // Recurse for groups
    if let group = element as? PBXGroup {
      let children = group.children
      for (index, child) in children.enumerated() {
        let childIsLast = (index == children.count - 1)
        printTreeNode(
          child, prefix: prefix + continuation, isLast: childIsLast, parentPath: childPath)
      }
    }
  }

  // MARK: - Save
  func save() throws {
    try profiler?.measureOperation("save") {
      try _save()
    } ?? _save()

    // Print performance stats if verbose
    profiler?.printTimingReport()
    if profiler != nil {
      cacheManager.printCacheStatistics()
    }
  }

  private func _save() throws {
    // Validate before saving
    let issues = validate()
    if !issues.isEmpty {
      print("⚠️  Validation issues found:")
      issues.forEach { print("  - \($0)") }
    }

    // Create backup for atomic write
    let backupPath = Path("\(projectPath.string).tmp")
    let fileManager = FileManager.default

    // Backup existing project
    if fileManager.fileExists(atPath: projectPath.string) {
      try fileManager.copyItem(atPath: projectPath.string, toPath: backupPath.string)
    }

    do {
      // Write to project
      try xcodeproj.write(path: projectPath)

      // Remove backup on success
      if fileManager.fileExists(atPath: backupPath.string) {
        try fileManager.removeItem(atPath: backupPath.string)
      }

      print("💾 Project saved successfully")
    } catch {
      // Restore from backup on failure
      if fileManager.fileExists(atPath: backupPath.string) {
        if fileManager.fileExists(atPath: projectPath.string) {
          try fileManager.removeItem(atPath: projectPath.string)
        }
        try fileManager.moveItem(atPath: backupPath.string, toPath: projectPath.string)
        print("⚠️  Save failed, restored from backup")
      }
      throw error
    }
  }
}
