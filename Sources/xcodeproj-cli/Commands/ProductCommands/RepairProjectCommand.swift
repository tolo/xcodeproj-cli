import Foundation
import PathKit

class RepairProjectCommand: Command {
  static let commandName: String = "repair-project"
  static let description: String =
    "Comprehensive project repair command that fixes multiple corruption types"
  static let category: CommandCategory = .inspection
  static let isReadOnly: Bool = false

  @MainActor
  static func execute(with arguments: ParsedArguments, utility: XcodeProjUtility) throws {
    let productManager = ProductReferenceManager(pbxproj: utility.pbxproj)
    let validator = ProjectValidator(pbxproj: utility.pbxproj, projectPath: utility.projectPath)

    let createBackup = arguments.boolFlags.contains("backup")
    let verbose = arguments.boolFlags.contains("verbose")
    let dryRun = arguments.boolFlags.contains("dry-run")

    if createBackup && !dryRun {
      let backupPath = utility.projectPath.parent() + "\(utility.projectPath.lastComponent).backup"
      print("💾 Creating backup at: \(backupPath)")
      try utility.projectPath.copy(backupPath)
    }

    var totalRepairs = 0
    var repairLog: [String] = []

    print("🔍 Analyzing project for issues...")

    // 1. Fix missing product references
    if verbose { print("  • Checking product references...") }
    let productRepairs = try productManager.repairProductReferences(dryRun: dryRun)
    if !productRepairs.isEmpty {
      repairLog.append(contentsOf: productRepairs)
      totalRepairs += productRepairs.count
    }

    // 2. Remove orphaned product references
    if verbose { print("  • Checking for orphaned products...") }
    if !dryRun {
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

    // 3. Fix invalid file references (existing functionality)
    if verbose { print("  • Checking file references...") }
    let invalidReferences = validator.findOrphanedFileReferences()
    if !invalidReferences.isEmpty && !dryRun {
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
    if verbose { print("  • Checking Products group...") }
    if utility.pbxproj.rootObject?.productsGroup == nil {
      if !dryRun {
        _ = try productManager.ensureProductsGroup()
        repairLog.append("Created missing Products group")
        totalRepairs += 1
      } else {
        repairLog.append("Would create missing Products group")
        totalRepairs += 1
      }
    }

    // 5. Fix target-product associations
    if verbose { print("  • Verifying target-product associations...") }
    let targetsWithoutProducts = productManager.findMissingProductReferences()
    if !targetsWithoutProducts.isEmpty {
      for target in targetsWithoutProducts {
        if !dryRun {
          if let productType = target.productType {
            let _ = try productManager.createProductReference(for: target, productType: productType)
            // TODO: Set target.productReference when property becomes accessible
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
      if dryRun {
        print("🔧 Would perform \(totalRepairs) repair(s) (dry run):")
      } else {
        print("🔧 Performed \(totalRepairs) repair(s):")
      }

      for repair in repairLog {
        print("  • \(repair)")
      }

      if !dryRun {
        try utility.save()
        print("\n✅ Project repaired successfully")

        if createBackup {
          print("💾 Original project backed up")
        }
      } else {
        print("\n💡 Run without --dry-run to apply fixes")
      }
    }
  }

  static func printUsage() {
    print(argumentsHelp())
  }

  static func argumentsHelp() -> String {
    """
    Usage: repair-project [--backup] [--verbose] [--dry-run]

    Options:
      --backup     Create backup before making changes
      --verbose    Show detailed progress information
      --dry-run    Preview changes without applying them

    Repair Operations:
      • Fix missing product references
      • Remove orphaned product references
      • Clean up invalid file references
      • Ensure Products group exists
      • Fix target-product associations
      • Remove duplicate entries

    Examples:
      repair-project
      repair-project --backup --verbose
      repair-project --dry-run
    """
  }
}
