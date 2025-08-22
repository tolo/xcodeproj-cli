import Foundation

/// Represents a validation issue found during project analysis
struct ValidationIssue: Sendable {
    enum IssueType: Sendable {
        case missingProductReference
        case orphanedProductReference
        case missingProductsGroup
        case invalidProductPath
    }

    let type: IssueType
    let message: String

    // Structured data for programmatic access
    let targetName: String?
    let productName: String?
    let severity: Severity

    enum Severity: String, Sendable {
        case error
        case warning
        case info
    }

    init(
        type: IssueType,
        message: String,
        targetName: String? = nil,
        productName: String? = nil,
        severity: Severity = .error
    ) {
        self.type = type
        self.message = message
        self.targetName = targetName
        self.productName = productName
        self.severity = severity
    }
}