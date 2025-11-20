//
// CacheManager.swift
// xcodeproj-cli
//
// Cache manager for improving performance of Xcode project operations
//

import Foundation
@preconcurrency import XcodeProj

/// Manages performance caches for Xcode project operations
@MainActor
class CacheManager {
  // MARK: - Cache Storage

  private var groupCache: [String: PBXGroup] = [:]
  private var groupPathCache: [String: String] = [:]  // Maps group path to full resolved path
  private var targetCache: [String: PBXNativeTarget] = [:]

  /// File reference cache using multiple key formats:
  /// - Composite key: "{groupPath}/{fileName}" (e.g., "App/Models/User.swift")
  /// - Path-only: fileRef.path (backward compatibility)
  /// - Name-only: fileRef.name (backward compatibility)
  private var fileReferenceCache: [String: PBXFileReference] = [:]

  /// Track which group owns each file for group-aware lookups
  private var fileGroupMembership: [PBXFileReference: PBXGroup] = [:]

  private var buildPhaseCache: [String: [PBXBuildPhase]] = [:]  // Target name -> build phases

  private let pbxproj: PBXProj

  // MARK: - Cache Statistics

  private var cacheHits = 0
  private var cacheMisses = 0

  init(pbxproj: PBXProj) {
    self.pbxproj = pbxproj
    rebuildAllCaches()
  }

  // MARK: - Cache Rebuilding

  func rebuildAllCaches() {
    rebuildTargetCache()
    rebuildGroupCache()
    rebuildFileReferenceCache()
    rebuildBuildPhaseCache()
  }

  private func rebuildTargetCache() {
    targetCache.removeAll()
    for target in pbxproj.nativeTargets {
      targetCache[target.name] = target
    }
  }

  private func rebuildGroupCache() {
    groupCache.removeAll()
    groupPathCache.removeAll()

    // Proper error handling for rootGroup access
    do {
      guard let rootGroup = try pbxproj.rootGroup() else {
        print("⚠️  Unable to access root group: project may be corrupted")
        return
      }
      buildGroupCache(from: rootGroup, currentPath: "")
    } catch {
      // Log the error but continue - cache will be empty but not fatal
      print("⚠️  Unable to build group cache: \(error)")
    }
  }

  private func buildGroupCache(from group: PBXGroup, currentPath: String) {
    // Cache this group
    let groupName = group.name ?? group.path ?? ""
    if !groupName.isEmpty {
      let fullPath = currentPath.isEmpty ? groupName : "\(currentPath)/\(groupName)"
      groupCache[fullPath] = group
      groupPathCache[fullPath] = fullPath
    }

    // Recursively cache child groups
    for child in group.children {
      if let childGroup = child as? PBXGroup {
        let childName = childGroup.name ?? childGroup.path ?? ""
        let childPath = currentPath.isEmpty ? childName : "\(currentPath)/\(childName)"
        buildGroupCache(from: childGroup, currentPath: childPath)
      }
    }
  }

  private func rebuildFileReferenceCache() {
    fileReferenceCache.removeAll()
    fileGroupMembership.removeAll()

    // Walk group hierarchy to track membership and build composite keys
    do {
      guard let rootGroup = try pbxproj.rootGroup() else {
        print("⚠️  Unable to access root group for file reference cache")
        return
      }
      buildFileReferenceCache(from: rootGroup, currentPath: "")
    } catch {
      print("⚠️  Unable to build file reference cache: \(error)")
    }
  }

  private func buildFileReferenceCache(from group: PBXGroup, currentPath: String) {
    let groupName = group.name ?? group.path ?? ""
    let fullGroupPath = currentPath.isEmpty ? groupName : "\(currentPath)/\(groupName)"

    // Process files in this group
    for child in group.children {
      if let fileRef = child as? PBXFileReference {
        // Track group membership
        fileGroupMembership[fileRef] = group

        // Build composite cache key using fileRef.path (the relative path from group)
        // This matches how FileService creates cache keys
        if let relativePath = fileRef.path, !relativePath.isEmpty, !fullGroupPath.isEmpty {
          let compositeKey = "\(fullGroupPath)/\(relativePath)"
          fileReferenceCache[compositeKey] = fileRef
        }

        // Also cache by path alone for backward compatibility lookups
        if let path = fileRef.path {
          fileReferenceCache[path] = fileRef
        }
        // Cache by name only if different from path
        if let name = fileRef.name, name != fileRef.path {
          fileReferenceCache[name] = fileRef
        }
      } else if let childGroup = child as? PBXGroup {
        // Recursively process child groups
        let childName = childGroup.name ?? childGroup.path ?? ""
        let childPath = currentPath.isEmpty ? childName : "\(currentPath)/\(childName)"
        buildFileReferenceCache(from: childGroup, currentPath: childPath)
      }
    }
  }

  private func rebuildBuildPhaseCache() {
    buildPhaseCache.removeAll()
    for target in pbxproj.nativeTargets {
      buildPhaseCache[target.name] = target.buildPhases
    }
  }

  // MARK: - Cache Access Methods

  func getTarget(_ name: String) -> PBXNativeTarget? {
    if let target = targetCache[name] {
      cacheHits += 1
      return target
    }
    cacheMisses += 1
    return nil
  }

  func getGroup(_ path: String) -> PBXGroup? {
    if let group = groupCache[path] {
      cacheHits += 1
      return group
    }
    cacheMisses += 1
    return nil
  }

  func getFileReference(_ path: String) -> PBXFileReference? {
    if let fileRef = fileReferenceCache[path] {
      cacheHits += 1
      return fileRef
    }
    cacheMisses += 1
    return nil
  }

  func getBuildPhases(for targetName: String) -> [PBXBuildPhase]? {
    if let phases = buildPhaseCache[targetName] {
      cacheHits += 1
      return phases
    }
    cacheMisses += 1
    return nil
  }

  // MARK: - Cache Invalidation

  func invalidateTarget(_ name: String) {
    targetCache.removeValue(forKey: name)
    buildPhaseCache.removeValue(forKey: name)
  }

  func invalidateGroup(_ path: String) {
    groupCache.removeValue(forKey: path)
    groupPathCache.removeValue(forKey: path)

    // Also invalidate any subgroups that start with this path
    let keysToRemove = groupCache.keys.filter { $0.hasPrefix(path + "/") }
    for key in keysToRemove {
      groupCache.removeValue(forKey: key)
      groupPathCache.removeValue(forKey: key)
    }
  }

  func invalidateFileReference(_ path: String) {
    fileReferenceCache.removeValue(forKey: path)
  }

  func invalidateAllCaches() {
    groupCache.removeAll()
    groupPathCache.removeAll()
    targetCache.removeAll()
    fileReferenceCache.removeAll()
    fileGroupMembership.removeAll()
    buildPhaseCache.removeAll()
    rebuildAllCaches()
  }

  // MARK: - Cache Statistics

  func getCacheStatistics() -> (hits: Int, misses: Int, hitRate: Double) {
    let total = cacheHits + cacheMisses
    let hitRate = total > 0 ? Double(cacheHits) / Double(total) : 0.0
    return (hits: cacheHits, misses: cacheMisses, hitRate: hitRate)
  }

  func resetStatistics() {
    cacheHits = 0
    cacheMisses = 0
  }

  func printCacheStatistics() {
    let stats = getCacheStatistics()
    print("Cache Statistics:")
    print("  Hits: \(stats.hits)")
    print("  Misses: \(stats.misses)")
    print("  Hit Rate: \(String(format: "%.1f", stats.hitRate * 100))%")
    print("  Groups Cached: \(groupCache.count)")
    print("  Targets Cached: \(targetCache.count)")
    print("  File References Cached: \(fileReferenceCache.count)")
  }
}
