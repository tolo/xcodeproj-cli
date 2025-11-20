//
// TransactionService.swift
// xcodeproj-cli
//

import Foundation
@preconcurrency import PathKit

/// Service for transaction management with backup and rollback support
@MainActor
final class TransactionService {
  private let projectPath: Path
  private let saveHandler: () throws -> Void
  private var transactionBackupPath: Path?
  private var orphanedBackups: Set<Path> = []  // Track backups that failed to clean up

  init(projectPath: Path, saveHandler: @escaping () throws -> Void) {
    self.projectPath = projectPath
    self.saveHandler = saveHandler
  }

  // MARK: - Transaction Support

  func beginTransaction() throws {
    guard transactionBackupPath == nil else {
      throw ProjectError.operationFailed("Transaction already in progress")
    }

    let backupPath = Path("\(projectPath.string).transaction")
    if FileManager.default.fileExists(atPath: projectPath.string) {
      // Remove orphaned backup from previous crashed test/operation
      if FileManager.default.fileExists(atPath: backupPath.string) {
        try FileManager.default.removeItem(atPath: backupPath.string)
      }
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
    try saveHandler()

    // Remove backup - only clear transaction state after successful cleanup
    do {
      if FileManager.default.fileExists(atPath: backupPath.string) {
        try FileManager.default.removeItem(atPath: backupPath.string)
      }
      // Only clear transaction state if cleanup succeeded
      transactionBackupPath = nil
      print("✅ Transaction committed")
    } catch {
      // Backup cleanup failed - track orphaned backup but clear transaction state
      orphanedBackups.insert(backupPath)
      transactionBackupPath = nil
      print("⚠️  Transaction committed but backup cleanup failed: \(error.localizedDescription)")
      print("ℹ️  Orphaned backup tracked for later cleanup: \(backupPath.lastComponent)")
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

  // MARK: - Orphaned Backup Cleanup

  func cleanupOrphanedBackups() -> Int {
    var cleanedCount = 0
    var stillOrphaned: Set<Path> = []

    for backupPath in orphanedBackups {
      do {
        if FileManager.default.fileExists(atPath: backupPath.string) {
          try FileManager.default.removeItem(atPath: backupPath.string)
          cleanedCount += 1
        }
        // Successfully cleaned (or file no longer exists)
      } catch {
        // Still failed to clean - keep tracking it
        stillOrphaned.insert(backupPath)
        print("⚠️  Failed to clean orphaned backup: \(backupPath.lastComponent)")
      }
    }

    // Update orphaned backups set to only contain ones we still couldn't clean
    orphanedBackups = stillOrphaned

    if cleanedCount > 0 {
      print("🧹 Cleaned up \(cleanedCount) orphaned backup file(s)")
    }

    return cleanedCount
  }

  /// Get count of orphaned backups that need cleanup
  var orphanedBackupCount: Int {
    return orphanedBackups.count
  }
}
