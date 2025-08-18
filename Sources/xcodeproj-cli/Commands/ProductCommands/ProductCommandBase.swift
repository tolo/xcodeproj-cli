import Foundation

/// Base class for product-related commands to reduce code duplication
@MainActor
class ProductCommandBase {

  /// Execute an operation and save the project if successful
  static func executeWithSave<T>(
    with arguments: ParsedArguments,
    utility: XcodeProjUtility,
    operation: (ProductReferenceManager) throws -> T
  ) throws -> T {
    let productManager = ProductReferenceManager(pbxproj: utility.pbxproj)
    let result = try operation(productManager)
    try utility.save()
    return result
  }

  /// Common validation for target name argument with security checks
  static func validateTargetArgument(_ arguments: ParsedArguments) throws -> String? {
    guard let targetName = arguments.positional.first, !targetName.isEmpty else {
      return nil
    }

    // Apply comprehensive security validation
    try validateTargetNameSecurity(targetName)

    return targetName
  }

  /// Generic security validation for names (targets, products, etc.)
  private static func validateNameSecurity(_ name: String, nameType: String) throws {
    // Check for empty or whitespace-only names
    guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw ProjectError.invalidArguments("\(nameType) cannot be empty or whitespace")
    }

    // Check for reasonable length (max 255 characters)
    guard name.count <= 255 else {
      throw ProjectError.invalidArguments("\(nameType) cannot exceed 255 characters")
    }

    // Check for path traversal attempts
    guard !name.contains("../") && !name.contains("..\\") else {
      throw ProjectError.invalidArguments("\(nameType) cannot contain path traversal sequences")
    }

    // Check for invalid characters that could cause issues
    let invalidCharacters = CharacterSet(charactersIn: "<>:\"|?*")
    guard name.rangeOfCharacter(from: invalidCharacters) == nil else {
      throw ProjectError.invalidArguments("\(nameType) contains invalid characters (<>:\"|?*)")
    }

    // Check for control characters
    guard name.rangeOfCharacter(from: .controlCharacters) == nil else {
      throw ProjectError.invalidArguments("\(nameType) cannot contain control characters")
    }

    // Check for null bytes
    guard !name.contains("\0") else {
      throw ProjectError.invalidArguments("\(nameType) cannot contain null bytes")
    }
  }

  /// Security validation for target names
  private static func validateTargetNameSecurity(_ name: String) throws {
    try validateNameSecurity(name, nameType: "Target name")
  }

  /// Security validation for product names (public for use by commands)
  static func validateProductNameSecurity(_ name: String) throws {
    try validateNameSecurity(name, nameType: "Product name")
  }

  /// Common error message formatting
  static func formatErrorMessage(_ error: Error) -> String {
    if let projectError = error as? ProjectError {
      return projectError.description
    }
    return "Error: \(error.localizedDescription)"
  }

  /// Common success message formatting
  static func formatSuccessMessage(operation: String, count: Int) -> String {
    if count == 0 {
      return "✅ No issues found - \(operation) completed successfully"
    } else if count == 1 {
      return "✅ \(operation) completed successfully - fixed 1 issue"
    } else {
      return "✅ \(operation) completed successfully - fixed \(count) issues"
    }
  }
}
