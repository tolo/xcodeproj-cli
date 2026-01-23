//
// UnlinkPackageProductCommand.swift
// xcodeproj-cli
//

import ArgumentParser
import Foundation

/// Unlink a Swift Package product from a target without removing the package
struct UnlinkPackageProductCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "unlink-package-product",
    abstract: "Unlink a Swift Package product from a target",
    discussion: """
      Removes a Swift Package product dependency from a target without removing
      the package from the project. Useful when a target should inherit package
      access from a host app rather than linking directly.

      Example:
        xcodeproj-cli unlink-package-product Alamofire --target MyAppTests
      """
  )

  @OptionGroup var global: GlobalOptions

  @Argument(help: "Name of the package product to unlink (e.g., 'Alamofire')")
  var productName: String

  @Option(
    name: [.customLong("target"), .customShort("t")],
    help: "Target to unlink the package product from")
  var target: String

  @MainActor
  func run() async throws {
    let services = try ProjectServiceFactory.create(from: global)
    try services.utility.unlinkPackageProduct(productName, from: target)
    try services.save()
  }
}
