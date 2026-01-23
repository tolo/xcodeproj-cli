//
// LinkPackageProductCommand.swift
// xcodeproj-cli
//

import ArgumentParser
import Foundation

/// Link an existing Swift Package product to a target
struct LinkPackageProductCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "link-package-product",
    abstract: "Link a Swift Package product to a target",
    discussion: """
      Links an existing Swift Package product to a target. The package must already
      be added to the project. Use this when you need to link a package to additional
      targets after initial setup.

      Examples:
        xcodeproj-cli link-package-product Alamofire --target MyApp
        xcodeproj-cli link-package-product RealmSwift --target MyApp --package https://github.com/realm/realm-swift.git
      """
  )

  @OptionGroup var global: GlobalOptions

  @Argument(help: "Name of the package product to link (e.g., 'Alamofire')")
  var productName: String

  @Option(
    name: [.customLong("target"), .customShort("t")],
    help: "Target to link the package product to")
  var target: String

  @Option(
    name: .long,
    help: "Package URL for disambiguation when product name doesn't match package URL")
  var package: String?

  @MainActor
  func run() async throws {
    let services = try ProjectServiceFactory.create(from: global)
    try services.utility.linkPackageProduct(productName, to: target, packageURL: package)
    try services.save()
  }
}
