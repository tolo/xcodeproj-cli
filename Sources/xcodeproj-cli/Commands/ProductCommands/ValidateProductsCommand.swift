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

        // Fix issues with fresh validation to prevent TOCTOU race conditions
        for issue in issues {
          switch issue.type {
          case .missingProductReference:
            // Extract target name from message
            if let targetName = extractTargetName(from: issue.message) {
              // Re-validate this specific target to ensure it still needs fixing
              if let target = utility.pbxproj.nativeTargets.first(where: { $0.name == targetName }),
                 target.product == nil {
                try productManager.addProductReference(to: target)
                print("  ✅ Fixed missing product reference for '\(targetName)'")
                fixedCount += 1
              }
            }
          case .missingProductsGroup:
            // Re-check if Products group is still missing
            if utility.pbxproj.rootObject?.productsGroup == nil {
              _ = try productManager.ensureProductsGroup()
              print("  ✅ Created missing Products group")
              fixedCount += 1
            }
          case .orphanedProductReference:
            // These will be handled by removeOrphanedProducts with fresh validation
            break
          case .invalidProductPath:
            // Would need specific repair logic for path issues
            break
          }
        }

        // Remove orphaned products with fresh validation
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
    // Use safer string parsing instead of regex to avoid ReDoS vulnerabilities
    
    let prefix = "Target '"
    let suffix = "' is missing product reference"
    
    guard message.hasPrefix(prefix) && message.hasSuffix(suffix) else {
      return nil
    }
    
    // Add bounds checking to prevent string index out of bounds
    guard message.count >= (prefix.count + suffix.count) else {
      return nil
    }
    
    let startIndex = message.index(message.startIndex, offsetBy: prefix.count)
    let endIndex = message.index(message.endIndex, offsetBy: -suffix.count)
    
    guard startIndex < endIndex else {
      return nil
    }
    
    let targetName = String(message[startIndex..<endIndex])
    
    // Validate target name to ensure it's reasonable
    guard !targetName.isEmpty,
          targetName.count <= 255,
          !targetName.contains("'") else {
      return nil
    }
    
    return targetName
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
