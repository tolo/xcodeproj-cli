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
    
    /// Common validation for target name argument
    static func validateTargetArgument(_ arguments: ParsedArguments) throws -> String? {
        guard let targetName = arguments.positional.first, !targetName.isEmpty else {
            return nil
        }
        
        // Basic validation
        guard targetName.count <= 255 else {
            throw ProjectError.invalidArguments("Target name cannot exceed 255 characters")
        }
        
        return targetName
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