//
// RepairProjectCommand.swift
// xcodeproj-cli
//
// ArgumentParser command for comprehensive project repair
//

import ArgumentParser
import Foundation
@preconcurrency import PathKit

/// ArgumentParser command for comprehensive project repair
struct RepairProjectCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "repair-project",
    abstract: "Comprehensive project repair command that fixes multiple corruption types"
  )

  @OptionGroup var global: GlobalOptions

  @Flag(help: "Create backup before making changes")
  var backup: Bool = false

  @MainActor
  func run() async throws {
    let services = try ProjectServiceFactory.create(from: global)
    let productManager = ProductReferenceManager(pbxproj: services.utility.pbxproj)
    let validator = ProjectValidator(
      pbxproj: services.utility.pbxproj,
      projectPath: services.utility.projectPath
    )

    if backup && !global.dryRun {
      let backupPath =
        services.utility.projectPath.parent()
        + "\(services.utility.projectPath.lastComponent).backup"
      print("💾 Creating backup at: \(backupPath)")
      try services.utility.projectPath.copy(backupPath)
    }

    var totalRepairs = 0
    var repairLog: [String] = []

    print("🔍 Analyzing project for issues...")

    // 1. Fix missing product references
    if global.verbose { print("  • Checking product references...") }
    let productRepairs = try productManager.repairProductReferences(dryRun: global.dryRun)
    if !productRepairs.isEmpty {
      repairLog.append(contentsOf: productRepairs)
      totalRepairs += productRepairs.count
    }

    // 2. Remove orphaned product references
    if global.verbose { print("  • Checking for orphaned products...") }
    if !global.dryRun {
      let orphanedCount = try productManager.removeOrphanedProducts()
      if orphanedCount > 0 {
        let message = "Removed \(orphanedCount) orphaned product reference(s)"
        repairLog.append(message)
        totalRepairs += orphanedCount
      }
    } else {
      let orphaned = productManager.findOrphanedProducts()
      if !orphaned.isEmpty {
        let message = "Would remove \(orphaned.count) orphaned product reference(s)"
        repairLog.append(message)
        totalRepairs += orphaned.count
      }
    }

    // 3. Fix invalid file references
    if global.verbose { print("  • Checking file references...") }
    let invalidReferences = validator.findOrphanedFileReferences()
    if !invalidReferences.isEmpty && !global.dryRun {
      try validator.removeOrphanedFileReferences()
      let message = "Removed \(invalidReferences.count) invalid file reference(s)"
      repairLog.append(message)
      totalRepairs += invalidReferences.count
    } else if !invalidReferences.isEmpty {
      let message = "Would remove \(invalidReferences.count) invalid file reference(s)"
      repairLog.append(message)
      totalRepairs += invalidReferences.count
    }

    // 4. Ensure Products group exists
    if global.verbose { print("  • Checking Products group...") }
    if services.utility.pbxproj.rootObject?.productsGroup == nil {
      if !global.dryRun {
        _ = try productManager.ensureProductsGroup()
        repairLog.append("Created missing Products group")
        totalRepairs += 1
      } else {
        repairLog.append("Would create missing Products group")
        totalRepairs += 1
      }
    }

    // 5. Fix target-product associations
    if global.verbose { print("  • Verifying target-product associations...") }
    let targetsWithoutProducts = productManager.findMissingProductReferences()
    if !targetsWithoutProducts.isEmpty {
      for target in targetsWithoutProducts {
        if !global.dryRun {
          if let productType = target.productType {
            let productRef = try productManager.createProductReference(
              for: target,
              productType: productType
            )
            target.product = productRef
          }
        }
        let message = "Fixed target-product association for '\(target.name)'"
        repairLog.append(message)
        totalRepairs += 1
      }
    }

    // Report results
    if totalRepairs == 0 {
      print("✅ Project is in good condition - no repairs needed")
    } else {
      if global.dryRun {
        print("🔧 Would perform \(totalRepairs) repair(s) (dry run):")
      } else {
        print("🔧 Performed \(totalRepairs) repair(s):")
      }

      for repair in repairLog {
        print("  • \(repair)")
      }

      if !global.dryRun {
        try services.save()
        print("\n✅ Project repaired successfully")

        if backup {
          print("💾 Original project backed up")
        }
      } else {
        print("\n💡 Run without --dry-run to apply fixes")
      }
    }
  }
}
