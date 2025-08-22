import Foundation
import PathKit

class RepairProductReferencesCommand: Command {
  static let commandName: String = "repair-product-references"
  static let description: String =
    "Automatically detect and fix missing or broken product references for all targets"
  static let category: CommandCategory = .inspection
  static let isReadOnly: Bool = false

  @MainActor
  static func execute(with arguments: ParsedArguments, utility: XcodeProjUtility) throws {
    let productManager = ProductReferenceManager(pbxproj: utility.pbxproj)

    let dryRun = arguments.boolFlags.contains("dry-run")

    let targetNames: [String]?
    if let targetsArg = arguments.flags["targets"] {
      targetNames = targetsArg.split(separator: ",").map {
        String($0).trimmingCharacters(in: .whitespaces)
      }
    } else {
      targetNames = nil
    }

    print("🔍 Analyzing product references...")

    let repaired = try productManager.repairProductReferences(
      dryRun: dryRun, targetNames: targetNames)

    if repaired.isEmpty {
      print("✅ All product references are properly configured")
    } else {
      if dryRun {
        print("🔧 Would repair the following issues (dry run):")
      } else {
        print("🔧 Repaired the following issues:")
      }

      for issue in repaired {
        print("  • \(issue)")
      }

      if !dryRun {
        try utility.save()
        print("✅ Product references repaired successfully")
      } else {
        print("💡 Run without --dry-run to apply fixes")
      }
    }
  }

  static func printUsage() {
    print(argumentsHelp())
  }

  static func argumentsHelp() -> String {
    """
    Usage: repair-product-references [--dry-run] [--targets <targets>]

    Automatically detects and fixes missing or broken product references in your Xcode project.
    Product references link targets to their build outputs in the Products group.

    Options:
      --dry-run            Preview changes without applying them
      --targets <list>     Comma-separated list of specific targets to repair

    What This Command Does:
      • Creates missing product references for targets
      • Links product references to their corresponding targets
      • Ensures Products group exists and is properly organized
      • Validates and repairs product reference integrity

    Examples:
      repair-product-references
      repair-product-references --dry-run
      repair-product-references --targets "MyApp,MyFramework"
    """
  }
}
