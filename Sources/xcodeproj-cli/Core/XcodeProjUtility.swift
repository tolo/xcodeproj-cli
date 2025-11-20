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
  private lazy var buildPhaseManager = BuildPhaseManager(pbxproj: pbxproj)
  private let cacheManager: CacheManager
  private let profiler: PerformanceProfiler?

  // Services
  private let transactionService: TransactionService

  private lazy var validationService = ValidationService(
    pbxproj: pbxproj,
    buildPhaseManager: buildPhaseManager,
    projectPath: projectPath
  )

  private lazy var treeDisplayService = TreeDisplayService(
    pbxproj: pbxproj,
    projectPath: projectPath
  )

  private lazy var pathUpdateService = PathUpdateService(pbxproj: pbxproj)

  private lazy var groupService = GroupService(
    pbxproj: pbxproj,
    cacheManager: cacheManager,
    buildPhaseManager: buildPhaseManager,
    projectPath: projectPath,
    profiler: profiler
  )

  private lazy var fileService: FileService = {
    let service = FileService(
      pbxproj: pbxproj,
      projectPath: projectPath,
      cacheManager: cacheManager,
      buildPhaseManager: buildPhaseManager,
      profiler: profiler
    )
    service.setGroupService(groupService)
    return service
  }()

  private lazy var targetService = TargetService(
    pbxproj: pbxproj,
    cacheManager: cacheManager,
    buildPhaseManager: buildPhaseManager,
    profiler: profiler
  )

  private lazy var buildSettingsService = BuildSettingsService(
    pbxproj: pbxproj,
    cacheManager: cacheManager,
    profiler: profiler
  )

  private lazy var packageService = PackageService(
    pbxproj: pbxproj,
    cacheManager: cacheManager,
    profiler: profiler
  )

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

    // Initialize TransactionService
    self.transactionService = TransactionService(projectPath: projectPath) {
      [unowned xcodeproj, projectPath] in
      try xcodeproj.write(path: projectPath)
    }
  }

  // MARK: - Transaction Support
  func beginTransaction() throws {
    try transactionService.beginTransaction()
  }

  func commitTransaction() throws {
    try transactionService.commitTransaction()
  }

  func rollbackTransaction() throws {
    try transactionService.rollbackTransaction()
  }

  func cleanupOrphanedBackups() -> Int {
    transactionService.cleanupOrphanedBackups()
  }

  // MARK: - File Operations
  func addFile(path: String, to groupPath: String, targets: [String]) throws {
    try fileService.addFile(path: path, to: groupPath, targets: targets)
  }

  func addFiles(_ files: [(path: String, group: String)], to targets: [String]) throws {
    try fileService.addFiles(files, to: targets)
  }

  func addFolder(
    path: String, to groupPath: String, targets: [String], recursive: Bool = false,
    createGroups: Bool = false
  ) throws {
    try fileService.addFolder(
      folderPath: path, to: groupPath, targets: targets, recursive: recursive,
      ensureGroupHierarchyFunc: { [weak self] path in
        guard let self = self else { return nil }
        if createGroups {
          return try self.groupService.ensureGroupHierarchy(path)
        }
        return nil
      })
  }

  func addSynchronizedFolder(folderPath: String, to groupPath: String, targets: [String]) throws {
    try fileService.addSynchronizedFolder(folderPath: folderPath, to: groupPath, targets: targets)
  }

  func removeFile(_ filePath: String) throws {
    try fileService.removeFile(filePath)
  }

  func moveFile(from oldPath: String, to newPath: String) throws {
    try fileService.moveFile(from: oldPath, to: newPath)
  }

  func moveFileToGroup(filePath: String, targetGroup: String) throws {
    try fileService.moveFileToGroup(filePath: filePath, targetGroup: targetGroup)
  }

  func addFileToTarget(path: String, targetName: String) throws {
    try fileService.addFileToTarget(path: path, targetName: targetName)
  }

  func removeFileFromTarget(path: String, targetName: String) throws {
    try fileService.removeFileFromTarget(path: path, targetName: targetName)
  }

  // MARK: - Group Operations
  func ensureGroupHierarchy(_ path: String) throws -> PBXGroup? {
    try groupService.ensureGroupHierarchy(path)
  }

  func createGroups(_ groupPaths: [String]) throws {
    try groupService.createGroups(groupPaths)
  }

  func findGroupAtPath(_ path: String) -> PBXGroup? {
    groupService.findGroupAtPath(path)
  }

  func findGroupByNameOrPath(_ identifier: String) -> PBXGroup? {
    groupService.findGroupByNameOrPath(identifier)
  }

  func removeGroup(_ groupPath: String) throws {
    try groupService.removeGroup(groupPath)
  }

  func removeFolder(_ folderPath: String) throws {
    try groupService.removeFolder(folderPath)
  }

  // MARK: - Target Operations
  func addTarget(name: String, productType: String, bundleId: String, platform: String = "iOS")
    throws
  {
    try targetService.addTarget(
      name: name, productType: productType, bundleId: bundleId, platform: platform)
  }

  func duplicateTarget(source: String, newName: String, newBundleId: String? = nil) throws {
    try targetService.duplicateTarget(source: source, newName: newName, newBundleId: newBundleId)
  }

  func removeTarget(name: String) throws {
    try targetService.removeTarget(name: name)
  }

  func addDependency(to targetName: String, dependsOn dependencyName: String) throws {
    try targetService.addDependency(to: targetName, dependsOn: dependencyName)
  }

  // MARK: - Frameworks
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
    try packageService.addSwiftPackage(url: url, requirement: requirement, to: targetName)
  }

  func removeSwiftPackage(url: String) throws {
    try packageService.removeSwiftPackage(url: url)
  }

  func listSwiftPackages() {
    packageService.listSwiftPackages()
  }

  func updateSwiftPackages(force: Bool = false) throws {
    try packageService.updateSwiftPackages(force: force)
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

  // MARK: - Path Updates
  func updateFilePaths(_ mappings: [String: String]) {
    pathUpdateService.updateFilePaths(mappings)
  }

  func updatePathsWithPrefix(from oldPrefix: String, to newPrefix: String) {
    pathUpdateService.updatePathsWithPrefix(from: oldPrefix, to: newPrefix)
  }

  // MARK: - Build Settings
  func updateBuildSettings(targets: [String], update: (inout BuildSettings) -> Void) {
    buildSettingsService.updateBuildSettings(targets: targets, update: update)
  }

  func setBuildSetting(key: String, value: String, targets: [String], configuration: String? = nil)
  {
    buildSettingsService.setBuildSetting(
      key: key, value: value, targets: targets, configuration: configuration)
  }

  func removeBuildSetting(key: String, targets: [String], configuration: String? = nil) {
    buildSettingsService.removeBuildSetting(
      key: key, targets: targets, configuration: configuration)
  }

  func getBuildSettings(for targetName: String, configuration: String? = nil) -> [String: [String:
    Any]]
  {
    buildSettingsService.getBuildSettings(for: targetName, configuration: configuration)
  }

  func listBuildConfigurations(for targetName: String? = nil) {
    buildSettingsService.listBuildConfigurations(for: targetName)
  }

  func listBuildSettings(
    targetName: String? = nil, configuration: String? = nil, showInherited: Bool = false,
    outputJSON: Bool = false, showAll: Bool = false
  ) {
    buildSettingsService.listBuildSettings(
      targetName: targetName, configuration: configuration, showInherited: showInherited,
      outputJSON: outputJSON, showAll: showAll)
  }

  // MARK: - Validation
  func validate() -> [String] {
    validationService.validate()
  }

  func listInvalidReferences() {
    validationService.listInvalidReferences()
  }

  func removeInvalidReferences() {
    validationService.removeInvalidReferences()
  }

  // MARK: - Tree Display
  func listProjectTree() {
    treeDisplayService.listProjectTree()
  }

  func listTargetTree(targetName: String) throws {
    try treeDisplayService.listTargetTree(targetName: targetName)
  }

  func listGroupsTree() {
    treeDisplayService.listGroupsTree()
  }

  func listGroupsWithNames() {
    guard let mainGroup = pbxproj.rootObject?.mainGroup else {
      print("⚠️  No main group found")
      return
    }

    print("📁 Project Groups\n")
    print("Format: [Tree Structure] → Simple Name | Full Path\n")

    printGroupsWithNames(mainGroup, prefix: "", isLast: true, path: "")

    print("\nUsage:")
    print("  • With simple name: --group Models")
    print("  • With full path: --group TestApp/Source/Models")
  }

  private func printGroupsWithNames(
    _ group: PBXGroup,
    prefix: String,
    isLast: Bool,
    path: String
  ) {
    let groupName = group.name ?? group.path ?? "Unnamed"
    let currentPath = path.isEmpty ? groupName : "\(path)/\(groupName)"

    // Tree structure
    let connector = isLast ? "└── " : "├── "
    let treeDisplay = prefix + connector + groupName

    // Usage info
    let simpleName = groupName
    let fullPath = currentPath

    print("\(treeDisplay) → '\(simpleName)' | '\(fullPath)'")

    // Recurse into child groups
    let childGroups = group.children.compactMap { $0 as? PBXGroup }
    let newPrefix = prefix + (isLast ? "    " : "│   ")

    for (index, childGroup) in childGroups.enumerated() {
      let isLastChild = index == childGroups.count - 1
      printGroupsWithNames(childGroup, prefix: newPrefix, isLast: isLastChild, path: currentPath)
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
      for issue in issues {
        print("  - \(issue)")
      }
    }

    // Create backup for atomic write
    let backupPath = Path("\(projectPath.string).tmp")
    let fileManager = FileManager.default

    // Backup existing project
    if fileManager.fileExists(atPath: projectPath.string) {
      try fileManager.copyItem(atPath: projectPath.string, toPath: backupPath.string)
    }

    do {
      // Write project
      try xcodeproj.write(path: projectPath)

      // Remove backup on success
      if fileManager.fileExists(atPath: backupPath.string) {
        try? fileManager.removeItem(atPath: backupPath.string)
      }

      print("✅ Successfully wrote project")
    } catch {
      // Restore from backup on failure
      if fileManager.fileExists(atPath: backupPath.string) {
        if fileManager.fileExists(atPath: projectPath.string) {
          try? fileManager.removeItem(atPath: projectPath.string)
        }
        try fileManager.moveItem(atPath: backupPath.string, toPath: projectPath.string)
      }
      throw error
    }
  }

  // MARK: - Helper Methods

  private func getSwiftVersion() -> String {
    // Try to detect from existing project first
    if let projectConfig = pbxproj.rootObject?.buildConfigurationList?.buildConfigurations.first,
      let existingVersion = projectConfig.buildSettings["SWIFT_VERSION"],
      case .string(let versionString) = existingVersion
    {
      return versionString
    }

    // Check environment variable override
    if let envSwiftVersion = ProcessInfo.processInfo.environment["XCODEPROJ_CLI_SWIFT_VERSION"] {
      return envSwiftVersion
    }

    // Try to detect current Swift version from runtime
    if #available(macOS 10.15, *) {
      // Use Swift version constants available at runtime
      #if swift(>=6.0)
        return "6.0"
      #elseif swift(>=5.9)
        return "5.9"
      #elseif swift(>=5.8)
        return "5.8"
      #else
        return "5.7"
      #endif
    }

    // Final fallback
    return "6.0"
  }
}
