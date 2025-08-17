import Foundation
import XcodeProj

extension PBXNativeTarget {
  /// Get the product name with appropriate file extension for product reference management
  func productNameForReference() -> String? {
    guard let productType = self.productType else { return nil }

    let baseName = self.productName ?? self.name
    let fileExt = productType.fileExtension

    if let ext = fileExt {
      return "\(baseName).\(ext)"
    } else {
      return baseName
    }
  }
}
