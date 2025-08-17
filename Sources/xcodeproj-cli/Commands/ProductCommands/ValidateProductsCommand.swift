import Foundation
import PathKit

class ValidateProductsCommand: Command {
  static let commandName: String = "validate-products"
  static let description: String =
    "Comprehensive validation of product references and Products group integrity"
  static let category: CommandCategory = .inspection
  static let isReadOnly: Bool = true

  @MainActor
  static func execute(with arguments: ParsedArguments, utility: XcodeProjUtility) throws {
    let productManager = ProductReferenceManager(pbxproj: utility.pbxproj)

    let shouldFix = arguments.boolFlags.contains("fix")

    print("🔍 Validating product references and Products group...")

    let issues = try productManager.validateProducts()

    if issues.isEmpty {
      print("✅ All product references are valid")
    } else {
      print("❌ Found \(issues.count) issue(s):")

      for issue in issues {
        print("  • \(issue.message)")
      }

      if shouldFix {
        print("\n🔧 Attempting to fix issues...")
        var fixedCount = 0

        for issue in issues {
          switch issue.type {
          case .missingProductReference:
            // Extract target name from message
            if let targetName = extractTargetName(from: issue.message) {
              if let target = utility.pbxproj.nativeTargets.first(where: { $0.name == targetName })
              {
                try productManager.addProductReference(to: target)
                print("  ✅ Fixed missing product reference for '\(targetName)'")
                fixedCount += 1
              }
            }
          case .missingProductsGroup:
            _ = try productManager.ensureProductsGroup()
            print("  ✅ Created missing Products group")
            fixedCount += 1
          case .orphanedProductReference:
            // These will be handled by removeOrphanedProducts
            break
          case .invalidProductPath:
            // Would need specific repair logic for path issues
            break
          }
        }

        // Remove orphaned products
        let orphanedCount = try productManager.removeOrphanedProducts()
        if orphanedCount > 0 {
          print("  ✅ Removed \(orphanedCount) orphaned product reference(s)")
          fixedCount += orphanedCount
        }

        if fixedCount > 0 {
          try utility.save()
          print("\n✅ Fixed \(fixedCount) issue(s) successfully")
        } else {
          print("\n⚠️  No automatic fixes available for remaining issues")
        }
      } else {
        print("\n💡 Run with --fix to automatically repair issues")
      }
    }
  }

  private static func extractTargetName(from message: String) -> String? {
    // Extract target name from message like "Target 'MyApp' is missing product reference"
    let pattern = #"Target '([^']+)' is missing product reference"#

    do {
      let regex = try NSRegularExpression(pattern: pattern, options: [])
      guard
        let match = regex.firstMatch(
          in: message, range: NSRange(message.startIndex..., in: message)),
        match.numberOfRanges > 1,
        let range = Range(match.range(at: 1), in: message)
      else {
        return nil
      }
      return String(message[range])
    } catch {
      print("⚠️  Error creating regex pattern for target name extraction: \(error)")
      return nil
    }
  }

  static func printUsage() {
    print(argumentsHelp())
  }

  static func argumentsHelp() -> String {
    """
    Usage: validate-products [--fix]

    Options:
      --fix    Automatically fix detected issues

    Examples:
      validate-products
      validate-products --fix
    """
  }
}
