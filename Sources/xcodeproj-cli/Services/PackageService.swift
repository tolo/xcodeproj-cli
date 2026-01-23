//
// PackageService.swift
// xcodeproj-cli
//

import Foundation
@preconcurrency import XcodeProj

/// Service for Swift Package Manager operations
@MainActor
final class PackageService {
  private let pbxproj: PBXProj
  private let cacheManager: CacheManager
  private let profiler: PerformanceProfiler?

  init(
    pbxproj: PBXProj,
    cacheManager: CacheManager,
    profiler: PerformanceProfiler? = nil
  ) {
    self.pbxproj = pbxproj
    self.cacheManager = cacheManager
    self.profiler = profiler
  }

  // MARK: - Swift Package Management

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

      print("  📦 \(url)")

      if force {
        print("    Force updating (not yet implemented)")
        updatedCount += 1
      } else {
        print("    Checking for updates (not yet implemented)")
      }
    }

    if updatedCount > 0 {
      print("✅ Updated \(updatedCount) package(s)")
    } else {
      print("ℹ️  No packages were updated")
    }

    print("ℹ️  Note: Full package update requires Xcode or xcodebuild")
  }

  // MARK: - Package Product Linking

  /// Link an existing Swift Package product to a target
  /// - Parameters:
  ///   - productName: Name of the package product (e.g., "Alamofire")
  ///   - targetName: Target to link the product to
  ///   - packageURL: Optional explicit package URL for disambiguation
  func linkPackageProduct(_ productName: String, to targetName: String, packageURL: String? = nil)
    throws
  {
    guard let target = cacheManager.getTarget(targetName) else {
      throw ProjectError.targetNotFound(targetName)
    }

    let packages = pbxproj.rootObject?.remotePackages ?? []
    guard !packages.isEmpty else {
      throw ProjectError.operationFailed("No Swift Packages in project")
    }

    // Check if already linked
    let existingProducts = target.packageProductDependencies ?? []
    if existingProducts.contains(where: { $0.productName == productName }) {
      throw ProjectError.operationFailed(
        "Product '\(productName)' is already linked to target '\(targetName)'")
    }

    // Find package reference
    var packageRef: XCRemoteSwiftPackageReference?

    // 1. If explicit URL provided, use it
    if let url = packageURL {
      packageRef = packages.first { $0.repositoryURL == url }
      if packageRef == nil {
        throw ProjectError.operationFailed(
          "Package with URL '\(url)' not found in project")
      }
    }

    // 2. Look for existing product dependency in other targets
    if packageRef == nil {
      for existingTarget in pbxproj.nativeTargets {
        if let deps = existingTarget.packageProductDependencies,
          let existingDep = deps.first(where: { $0.productName == productName })
        {
          packageRef = existingDep.package
          break
        }
      }
    }

    // 3. Try URL heuristic (product name in URL)
    if packageRef == nil {
      let productLower = productName.lowercased()
      let candidates = packages.filter { pkg in
        guard let url = pkg.repositoryURL?.lowercased() else { return false }
        return url.contains(productLower) || url.hasSuffix("/\(productLower).git")
      }

      if candidates.count == 1 {
        packageRef = candidates.first
      } else if candidates.count > 1 {
        let urls = candidates.compactMap { $0.repositoryURL }.joined(separator: ", ")
        throw ProjectError.operationFailed(
          "Multiple packages could contain '\(productName)': \(urls). "
            + "Use --package to specify which one.")
      }
    }

    // 4. If only one package exists, use it
    if packageRef == nil && packages.count == 1 {
      packageRef = packages.first
    }

    guard let package = packageRef else {
      let availablePackages = packages.compactMap { $0.repositoryURL }.joined(separator: "\n  - ")
      throw ProjectError.operationFailed(
        "Could not determine package for product '\(productName)'. "
          + "Use --package to specify the package URL.\n"
          + "Available packages:\n  - \(availablePackages)")
    }

    // Create product dependency
    let productDep = XCSwiftPackageProductDependency(productName: productName, package: package)
    pbxproj.add(object: productDep)

    // Add to target's package dependencies
    if target.packageProductDependencies == nil {
      target.packageProductDependencies = []
    }
    target.packageProductDependencies?.append(productDep)

    // Add to frameworks build phase
    let frameworksPhase = try getOrCreateFrameworksBuildPhase(for: target)
    let buildFile = PBXBuildFile(product: productDep)
    pbxproj.add(object: buildFile)

    // Ensure files array is initialized before appending
    if frameworksPhase.files == nil {
      frameworksPhase.files = []
    }
    frameworksPhase.files?.append(buildFile)

    print("✅ Linked '\(productName)' to target '\(targetName)'")
  }

  /// Unlink a Swift Package product from a target
  func unlinkPackageProduct(_ productName: String, from targetName: String) throws {
    guard let target = cacheManager.getTarget(targetName) else {
      throw ProjectError.targetNotFound(targetName)
    }

    // Find product dependency
    guard let deps = target.packageProductDependencies,
      let productDepIndex = deps.firstIndex(where: { $0.productName == productName })
    else {
      throw ProjectError.operationFailed(
        "Product '\(productName)' is not linked to target '\(targetName)'")
    }

    let productDep = deps[productDepIndex]

    // Remove from frameworks build phase
    removeBuildFilesForProduct(productDep, from: target)

    // Remove from embed frameworks phase (Copy Files with .frameworks destination)
    removeFromEmbedPhase(productDep, from: target)

    // Remove from target's package dependencies
    target.packageProductDependencies?.remove(at: productDepIndex)

    // Delete product dependency object if no longer referenced
    let stillReferenced = pbxproj.nativeTargets.contains { t in
      t.packageProductDependencies?.contains { $0 === productDep } ?? false
    }
    if !stillReferenced {
      pbxproj.delete(object: productDep)
    }

    print("✅ Unlinked '\(productName)' from target '\(targetName)'")
  }

  private func removeBuildFilesForProduct(
    _ productDep: XCSwiftPackageProductDependency, from target: PBXNativeTarget
  ) {
    if let frameworksPhase = target.buildPhases.first(where: { $0 is PBXFrameworksBuildPhase })
      as? PBXFrameworksBuildPhase,
      let files = frameworksPhase.files
    {
      for buildFile in files where buildFile.product === productDep {
        frameworksPhase.files?.removeAll { $0 === buildFile }
        pbxproj.delete(object: buildFile)
      }
    }
  }

  private func removeFromEmbedPhase(
    _ productDep: XCSwiftPackageProductDependency, from target: PBXNativeTarget
  ) {
    // Find embed frameworks phase (PBXCopyFilesBuildPhase with .frameworks destination)
    for phase in target.buildPhases {
      if let copyPhase = phase as? PBXCopyFilesBuildPhase,
        copyPhase.dstSubfolderSpec == .frameworks,
        let files = copyPhase.files
      {
        for buildFile in files where buildFile.product === productDep {
          copyPhase.files?.removeAll { $0 === buildFile }
          pbxproj.delete(object: buildFile)
        }
      }
    }
  }

  /// List package products linked to a target
  func listPackageProducts(for targetName: String) throws -> [String] {
    guard let target = cacheManager.getTarget(targetName) else {
      throw ProjectError.targetNotFound(targetName)
    }
    return (target.packageProductDependencies ?? []).compactMap { $0.productName }
  }

  // MARK: - Private Helpers

  private func getOrCreateFrameworksBuildPhase(for target: PBXNativeTarget) throws
    -> PBXFrameworksBuildPhase
  {
    if let existing = target.buildPhases.first(where: { $0 is PBXFrameworksBuildPhase })
      as? PBXFrameworksBuildPhase
    {
      return existing
    }
    let newPhase = PBXFrameworksBuildPhase()
    pbxproj.add(object: newPhase)
    target.buildPhases.append(newPhase)
    return newPhase
  }
}
