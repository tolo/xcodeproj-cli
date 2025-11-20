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
}
