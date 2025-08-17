import Foundation
import PathKit
import XcodeProj

class AddProductReferenceCommand: Command {
  static let commandName: String = "add-product-reference"
  static let description: String =
    "Manually add or update a product reference for a specific target"
  static let category: CommandCategory = .buildConfiguration
  static let isReadOnly: Bool = false

  @MainActor
  static func execute(with arguments: ParsedArguments, utility: XcodeProjUtility) throws {
    // Validate target name with security checks
    guard let targetName = try ProductCommandBase.validateTargetArgument(arguments) else {
      throw ProjectError.invalidArguments("Target name is required")
    }

    guard let target = utility.pbxproj.nativeTargets.first(where: { $0.name == targetName }) else {
      throw ProjectError.targetNotFound(targetName)
    }

    // Validate custom product name if provided
    let productName = arguments.flags["name"]
    if let name = productName {
      try ProductCommandBase.validateProductNameSecurity(name)
    }

    let productType: PBXProductType?
    if let typeString = arguments.flags["type"] {
      guard let type = PBXProductType(rawValue: typeString) else {
        throw ProjectError.invalidArguments("Invalid product type: \(typeString)")
      }
      productType = type
    } else {
      productType = nil
    }

    print("🔧 Adding product reference to target '\(targetName)'...")

    let finalProductName = try ProductCommandBase.executeWithSave(with: arguments, utility: utility) { productManager in
      try productManager.addProductReference(
        to: target, productName: productName, productType: productType)
      return productName ?? "\(targetName).app"
    }

    print("✅ Added product reference '\(finalProductName)' to target '\(targetName)'")
  }

  static func printUsage() {
    print(argumentsHelp())
  }

  static func argumentsHelp() -> String {
    """
    Usage: add-product-reference <target> [--name <product-name>] [--type <product-type>]

    Arguments:
      target               Name of the target to add product reference to

    Options:
      --name <name>        Custom name for the product (optional)
      --type <type>        Product type (e.g., com.apple.product-type.application)

    Common Product Types:
      com.apple.product-type.application          - iOS/macOS App
      com.apple.product-type.framework            - Framework
      com.apple.product-type.library.static       - Static Library
      com.apple.product-type.library.dynamic      - Dynamic Library
      com.apple.product-type.bundle.unit-test     - Unit Test Bundle
      com.apple.product-type.bundle.ui-testing    - UI Test Bundle
      com.apple.product-type.app-extension        - App Extension
      com.apple.product-type.tool                 - Command Line Tool

    Examples:
      add-product-reference MyApp
      add-product-reference MyFramework --type com.apple.product-type.framework
      add-product-reference MyApp --name "Custom App Name"
    """
  }
}
