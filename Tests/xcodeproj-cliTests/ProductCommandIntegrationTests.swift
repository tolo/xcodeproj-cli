import XCTest
import Foundation
import PathKit
@testable import xcodeproj_cli
import XcodeProj

final class ProductCommandIntegrationTests: XCTestCase {
    var tempDir: Path!
    var projectPath: Path!
    var utility: XcodeProjUtility!
    
    override func setUp() {
        super.setUp()
        
        // Create temporary directory
        let tempDirString = NSTemporaryDirectory() + "ProductCommandIntegrationTests-\(UUID().uuidString)"
        tempDir = Path(tempDirString)
        do {
            try tempDir.mkpath()
            
            // Create test project
            projectPath = tempDir + "TestProject.xcodeproj"
            try TestHelpers.createBasicProject(at: projectPath)
        } catch {
            XCTFail("Failed to set up test environment: \(error)")
            return
        }
    }
    
    override func tearDown() {
        utility = nil
        try? tempDir.delete()
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    @MainActor
    func setupUtility() throws {
        if utility == nil {
            utility = try XcodeProjUtility(path: projectPath.string)
        }
    }
    
    // MARK: - End-to-End Command Integration Tests
    
    @MainActor
    func testRepairProductReferencesCommandIntegration() throws {
        try setupUtility()
        
        // Create a target that needs repair
        let target = PBXNativeTarget(
            name: "TestApp",
            productName: "TestApp",
            productType: .application
        )
        utility.pbxproj.add(object: target)
        utility.pbxproj.rootObject?.targets.append(target)
        
        // Save project state before repair
        try utility.save()
        
        // Execute repair command - should throw library limitation
        let args = ParsedArguments(positional: [], flags: [:], boolFlags: [])
        
        XCTAssertThrowsError(try RepairProductReferencesCommand.execute(with: args, utility: utility)) { error in
            if let projectError = error as? ProjectError,
               case .libraryLimitation(_) = projectError {
                // Expected behavior
                XCTAssertTrue(true)
            } else {
                XCTFail("Expected ProjectError.libraryLimitation")
            }
        }
        
        // Project should still be valid despite limitation
        XCTAssertNoThrow(try utility.save())
        let reloadedUtility = try XcodeProjUtility(path: projectPath.string)
        XCTAssertNotNil(reloadedUtility.pbxproj.rootObject)
    }
    
    @MainActor
    func testValidateProductsCommandIntegration() throws {
        try setupUtility()
        
        // Create target with potential issues
        let target = PBXNativeTarget(
            name: "ValidationTarget",
            productName: "ValidationTarget", 
            productType: .application
        )
        utility.pbxproj.add(object: target)
        utility.pbxproj.rootObject?.targets.append(target)
        
        // Execute validate command (read-only)
        let args = ParsedArguments(positional: [], flags: [:], boolFlags: [])
        
        XCTAssertNoThrow(try ValidateProductsCommand.execute(with: args, utility: utility))
        
        // Verify project state unchanged after validation
        XCTAssertEqual(utility.pbxproj.nativeTargets.count, 1)
        XCTAssertEqual(utility.pbxproj.nativeTargets.first?.name, "ValidationTarget")
    }
    
    @MainActor
    func testAddProductReferenceCommandIntegration() throws {
        try setupUtility()
        
        // Create target
        let target = PBXNativeTarget(
            name: "AddRefTarget",
            productName: "AddRefTarget",
            productType: .framework
        )
        utility.pbxproj.add(object: target)
        utility.pbxproj.rootObject?.targets.append(target)
        
        // Execute add-product-reference command
        let args = ParsedArguments(
            positional: ["AddRefTarget"],
            flags: ["name": "CustomFramework.framework"],
            boolFlags: []
        )
        
        XCTAssertNoThrow(try AddProductReferenceCommand.execute(with: args, utility: utility))
        
        // Verify Products group exists
        XCTAssertNotNil(utility.pbxproj.rootObject?.productsGroup)
        
        // Verify project integrity after operation
        XCTAssertNoThrow(try utility.save())
    }
    
    @MainActor
    func testRepairProjectCommandIntegration() throws {
        try setupUtility()
        
        // Create broken target (missing build configurations)
        let brokenTarget = PBXNativeTarget(
            name: "BrokenTarget",
            productName: "BrokenTarget",
            productType: .application
        )
        brokenTarget.buildConfigurationList = nil // Broken state
        utility.pbxproj.add(object: brokenTarget)
        utility.pbxproj.rootObject?.targets.append(brokenTarget)
        
        // Execute repair project command - should throw library limitation
        let args = ParsedArguments(positional: [], flags: [:], boolFlags: [])
        
        XCTAssertThrowsError(try RepairProjectCommand.execute(with: args, utility: utility)) { error in
            if let projectError = error as? ProjectError,
               case .libraryLimitation(_) = projectError {
                // Expected behavior
                XCTAssertTrue(true)
            } else {
                XCTFail("Expected ProjectError.libraryLimitation")
            }
        }
        
        // Verify target still exists
        let repairedTarget = utility.pbxproj.nativeTargets.first { $0.name == "BrokenTarget" }
        XCTAssertNotNil(repairedTarget, "Target should exist")
        
        // Verify project can be saved
        XCTAssertNoThrow(try utility.save())
    }
    
    @MainActor
    func testRepairTargetsCommandIntegration() throws {
        try setupUtility()
        
        // Create target missing build phases
        let target = PBXNativeTarget(
            name: "EmptyTarget",
            productName: "EmptyTarget",
            productType: .application
        )
        // Intentionally leave buildPhases empty
        utility.pbxproj.add(object: target)
        utility.pbxproj.rootObject?.targets.append(target)
        
        // Execute repair targets command
        let args = ParsedArguments(positional: ["EmptyTarget"], flags: [:], boolFlags: [])
        
        XCTAssertNoThrow(try RepairTargetsCommand.execute(with: args, utility: utility))
        
        // Verify target has build phases now
        let repairedTarget = utility.pbxproj.nativeTargets.first { $0.name == "EmptyTarget" }
        XCTAssertFalse(repairedTarget?.buildPhases.isEmpty ?? true)
        
        // Verify project integrity
        XCTAssertNoThrow(try utility.save())
    }
    
    // MARK: - Command Error Handling Integration Tests
    
    @MainActor
    func testCommandErrorHandlingIntegration() throws {
        try setupUtility()
        
        // Test invalid target name
        let invalidArgs = ParsedArguments(
            positional: ["NonExistentTarget"],
            flags: [:],
            boolFlags: []
        )
        
        // Should throw appropriate error for non-existent target
        XCTAssertThrowsError(try AddProductReferenceCommand.execute(with: invalidArgs, utility: utility)) { error in
            if let projectError = error as? ProjectError,
               case .targetNotFound(let targetName) = projectError {
                XCTAssertEqual(targetName, "NonExistentTarget")
            } else {
                XCTFail("Expected ProjectError.targetNotFound but got: \(error)")
            }
        }
    }
    
    @MainActor
    func testCommandWithSecurityValidationIntegration() throws {
        try setupUtility()
        
        // Create target
        let target = PBXNativeTarget(
            name: "SecurityTest",
            productName: "SecurityTest",
            productType: .application
        )
        utility.pbxproj.add(object: target)
        utility.pbxproj.rootObject?.targets.append(target)
        
        // Test command with malicious input
        let maliciousArgs = ParsedArguments(
            positional: ["SecurityTest"],
            flags: ["name": "../../../malicious.app"],
            boolFlags: []
        )
        
        // Should reject malicious input
        XCTAssertThrowsError(try AddProductReferenceCommand.execute(with: maliciousArgs, utility: utility)) { error in
            if let projectError = error as? ProjectError,
               case .invalidArguments(let message) = projectError {
                XCTAssertTrue(message.contains("path traversal"))
            } else {
                XCTFail("Expected ProjectError.invalidArguments with path traversal message")
            }
        }
    }
    
    // MARK: - Performance Integration Tests
    
    @MainActor
    func testCommandPerformanceWithManyTargets() throws {
        try setupUtility()
        
        // Create many targets
        for i in 0..<50 {
            let target = PBXNativeTarget(
                name: "Target\(i)",
                productName: "Target\(i)",
                productType: .application
            )
            utility.pbxproj.add(object: target)
            utility.pbxproj.rootObject?.targets.append(target)
        }
        
        // Measure repair command performance
        let args = ParsedArguments(positional: [], flags: [:], boolFlags: [])
        
        let startTime = CFAbsoluteTimeGetCurrent()
        XCTAssertThrowsError(try RepairProductReferencesCommand.execute(with: args, utility: utility)) { error in
            if let projectError = error as? ProjectError,
               case .libraryLimitation(_) = projectError {
                // Expected behavior
                XCTAssertTrue(true)
            } else {
                XCTFail("Expected ProjectError.libraryLimitation")
            }
        }
        let executionTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Should fail quickly due to library limitation
        XCTAssertLessThan(executionTime, 1.0, "Should throw error quickly: \(executionTime) seconds")
        
        // Verify project integrity
        XCTAssertNoThrow(try utility.save())
    }
}