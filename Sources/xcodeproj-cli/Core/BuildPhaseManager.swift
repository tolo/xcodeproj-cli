//
// BuildPhaseManager.swift
// xcodeproj-cli
//
// Manages build phase operations to eliminate repetitive iteration patterns
//

import Foundation
@preconcurrency import XcodeProj

@MainActor
class BuildPhaseManager {
  private let pbxproj: PBXProj

  init(pbxproj: PBXProj) {
    self.pbxproj = pbxproj
  }

  // MARK: - Utility Methods

  /// Adds an item to an array only if it's not already present (using identity comparison)
  private func addUniqueByIdentity<T: AnyObject>(_ item: T, to array: inout [T]) {
    if !array.contains(where: { $0 === item }) {
      array.append(item)
    }
  }

  // MARK: - Build File Collection

  /// Finds all build files that reference the given file reference
  /// Returns an array to avoid Set crashes with duplicate PBXBuildFile elements (XcodeProj 9.4.3 bug)
  /// Uses ObjectIdentifier for O(1) duplicate detection performance
  func findBuildFiles(for fileReference: PBXFileReference) -> [PBXBuildFile] {
    var buildFiles: [PBXBuildFile] = []
    var seen = Set<ObjectIdentifier>()

    for target in pbxproj.nativeTargets {
      for buildPhase in target.buildPhases {
        let phaseFiles = getBuildPhaseFiles(buildPhase)
        for buildFile in phaseFiles where buildFile.file === fileReference {
          let id = ObjectIdentifier(buildFile)
          if !seen.contains(id) {
            seen.insert(id)
            buildFiles.append(buildFile)
          }
        }
      }
    }

    return buildFiles
  }

  /// Removes build files that match the given predicate from all build phases
  func removeBuildFiles(matching predicate: (PBXBuildFile) -> Bool) {
    for target in pbxproj.nativeTargets {
      for buildPhase in target.buildPhases {
        removeBuildFilesFromPhase(buildPhase, matching: predicate)
      }
    }
  }

  /// Removes build files for the given file reference from all build phases
  func removeBuildFiles(for fileReference: PBXFileReference) {
    removeBuildFiles { buildFile in
      buildFile.file === fileReference
    }
  }

  /// Adds a file to appropriate build phases based on file type
  /// Returns array of missing targets if any were not found
  @discardableResult
  func addFileToBuildPhases(
    fileReference: PBXFileReference,
    targets: [String],
    isCompilable: Bool
  ) -> [String] {
    var missingTargets: [String] = []

    for targetName in targets {
      guard let target = pbxproj.nativeTargets.first(where: { $0.name == targetName }) else {
        print("⚠️  Target '\(targetName)' not found")
        missingTargets.append(targetName)
        continue
      }

      if isCompilable {
        // Add to sources build phase
        guard let sourcesBuildPhase = XcodeProjectHelpers.sourceBuildPhase(for: target) else {
          print("⚠️  Target '\(targetName)' has no sources build phase")
          continue
        }

        let buildFile = PBXBuildFile(file: fileReference)
        pbxproj.add(object: buildFile)
        // Initialize files array if nil to prevent silent failures
        if sourcesBuildPhase.files == nil {
          sourcesBuildPhase.files = []
        }
        sourcesBuildPhase.files!.append(buildFile)
      } else {
        // Add to resources build phase for non-compilable files
        if let resourcesBuildPhase = target.buildPhases.first(where: {
          $0 is PBXResourcesBuildPhase
        }) as? PBXResourcesBuildPhase {
          let buildFile = PBXBuildFile(file: fileReference)
          pbxproj.add(object: buildFile)
          // Initialize files array if nil to prevent silent failures
          if resourcesBuildPhase.files == nil {
            resourcesBuildPhase.files = []
          }
          resourcesBuildPhase.files!.append(buildFile)
        }
      }
    }

    return missingTargets
  }

  // MARK: - Private Helpers

  /// Gets all files from a build phase, regardless of phase type
  private func getBuildPhaseFiles(_ buildPhase: PBXBuildPhase) -> [PBXBuildFile] {
    switch buildPhase {
    case let sourcesBuildPhase as PBXSourcesBuildPhase:
      return sourcesBuildPhase.files ?? []
    case let resourcesBuildPhase as PBXResourcesBuildPhase:
      return resourcesBuildPhase.files ?? []
    case let frameworksBuildPhase as PBXFrameworksBuildPhase:
      return frameworksBuildPhase.files ?? []
    case let copyFilesBuildPhase as PBXCopyFilesBuildPhase:
      return copyFilesBuildPhase.files ?? []
    default:
      return []
    }
  }

  /// Removes build files from a specific build phase that match the predicate
  private func removeBuildFilesFromPhase(
    _ buildPhase: PBXBuildPhase, matching predicate: (PBXBuildFile) -> Bool
  ) {
    switch buildPhase {
    case let sourcesBuildPhase as PBXSourcesBuildPhase:
      sourcesBuildPhase.files?.removeAll(where: predicate)
    case let resourcesBuildPhase as PBXResourcesBuildPhase:
      resourcesBuildPhase.files?.removeAll(where: predicate)
    case let frameworksBuildPhase as PBXFrameworksBuildPhase:
      frameworksBuildPhase.files?.removeAll(where: predicate)
    case let copyFilesBuildPhase as PBXCopyFilesBuildPhase:
      copyFilesBuildPhase.files?.removeAll(where: predicate)
    default:
      break
    }
  }
}
