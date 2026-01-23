//
// AddProductReferenceCommand.swift
// xcodeproj-cli
//
// ArgumentParser command for manually adding or updating a product reference for a specific target
//

import ArgumentParser
import Foundation
import XcodeProj

/// ArgumentParser command for adding product references
struct AddProductReferenceCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "add-product-reference",
    abstract: "Manually add or update a product reference for a specific target"
  )

  @OptionGroup var global: GlobalOptions

  @Argument(help: "Name of the target to add product reference to")
  var targetName: String

  @Option(help: "Custom name for the product (optional)")
  var name: String?

  @Option(help: "Product type (e.g., com.apple.product-type.application)")
  var type: String?

  @MainActor
  func run() async throws {
    let services = try ProjectServiceFactory.create(from: global)

    // Validate target name with security checks
    try SecurityUtils.validateProductNameSecurity(targetName)

    guard
      let target = services.utility.pbxproj.nativeTargets.first(where: { $0.name == targetName })
    else {
      throw ProjectError.targetNotFound(targetName)
    }

    // Validate custom product name if provided
    if let productName = name {
      try SecurityUtils.validateProductNameSecurity(productName)
    }

    let productType: PBXProductType?
    if let typeString = type {
      guard let parsedType = PBXProductType(rawValue: typeString) else {
        throw ProjectError.invalidArguments("Invalid product type: \(typeString)")
      }
      productType = parsedType
    } else {
      productType = nil
    }

    print("🔧 Adding product reference to target '\(targetName)'...")

    let productManager = ProductReferenceManager(pbxproj: services.utility.pbxproj)
    try productManager.addProductReference(
      to: target,
      productName: name,
      productType: productType
    )

    try services.save()

    let finalProductName = name ?? "\(targetName).app"
    print("✅ Added product reference '\(finalProductName)' to target '\(targetName)'")
  }
}
