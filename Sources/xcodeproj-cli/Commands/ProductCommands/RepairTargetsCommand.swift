import Foundation
import PathKit

class RepairTargetsCommand: Command {
  static let commandName: String = "repair-targets"
  static let description: String =
    "Fix common target-related issues including missing product references and build phases"
  static let category: CommandCategory = .inspection
  static let isReadOnly: Bool = false

  @MainActor
  static func execute(with arguments: ParsedArguments, utility: XcodeProjUtility) throws {
    let productManager = ProductReferenceManager(pbxproj: utility.pbxproj)

    let targetName = arguments.flags["target"]

    print("🔍 Analyzing targets for issues...")

    let repaired = try productManager.repairTargets(targetName: targetName)

    if repaired.isEmpty {
      if let target = targetName {
        print("✅ Target '\(target)' is properly configured")
      } else {
        print("✅ All targets are properly configured")
      }
    } else {
      print("🔧 Repaired the following issues:")

      for issue in repaired {
        print("  • \(issue)")
      }

      try utility.save()
      print("\n✅ Target repairs completed successfully")
    }
  }

  static func printUsage() {
    print(argumentsHelp())
  }

  static func argumentsHelp() -> String {
    """
    Usage: repair-targets [--target <name>]

    Options:
      --target <name>      Repair specific target (default: all targets)

    Repair Operations:
      • Add missing product references
      • Ensure required build phases exist
      • Fix missing build configurations
      • Repair product type inconsistencies

    Examples:
      repair-targets
      repair-targets --target MyApp
    """
  }
}
