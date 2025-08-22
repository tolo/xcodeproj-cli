import Foundation
import XcodeProj

/// Shared service for product reference validation logic
@MainActor
final class ProductValidationService: Sendable {
  private let pbxproj: PBXProj
  
  init(pbxproj: PBXProj) {
    self.pbxproj = pbxproj
  }
  
  /// Find orphaned product references in Products group that aren't referenced by any target
  func findOrphanedProducts() -> [PBXFileReference] {
    guard let productsGroup = pbxproj.rootObject?.productsGroup else { return [] }
    
    // Build set of all products referenced by targets for O(1) lookup
    let referencedProducts = Set(pbxproj.nativeTargets.compactMap { $0.product })
    
    // Find products in Products group that aren't referenced by any target
    return productsGroup.children
      .compactMap { $0 as? PBXFileReference }
      .filter { !referencedProducts.contains($0) }
  }
}