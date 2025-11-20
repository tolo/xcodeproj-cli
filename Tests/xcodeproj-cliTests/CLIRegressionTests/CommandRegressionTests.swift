//
// CommandRegressionTests.swift
// xcodeproj-cli Tests
//
// CLI regression tests for all commands
//

import XCTest
import Foundation

/// Comprehensive CLI regression tests for all commands
final class CommandRegressionTests: XCTestCase {

    private var testProjectPath: String!

    override func setUp() {
        super.setUp()
        // Create a test project for commands that need one
        do {
            testProjectPath = try CLITestHarness.createTestProject(named: "CLITestProject")
        } catch {
            XCTFail("Failed to create test project: \(error)")
        }
    }

    override func tearDown() {
        // Clean up test project
        if let projectPath = testProjectPath {
            CLITestHarness.cleanupTestProject(at: projectPath)
        }
        super.tearDown()
    }

    // MARK: - Inspection Commands

    func testValidateCommand() {
        let result = CLITestHarness.executeWithProject(
            testProjectPath,
            command: "validate"
        )

        if result.exitCode != 0 {
            print("❌ Test project path: \(testProjectPath)")
            print("❌ Exit code: \(result.exitCode)")
            print("❌ Stdout: \(result.stdout)")
            print("❌ Stderr: \(result.stderr)")
        }

        XCTAssertEqual(result.exitCode, 0, "validate should succeed")
        XCTAssertFalse(result.stdout.isEmpty, "validate should produce output")

        // Compare against golden file
        GoldenFileManager.assertMatchesGolden(result: result, name: "validate-clean")
    }

    func testListTargetsCommand() {
        let result = CLITestHarness.executeWithProject(
            testProjectPath,
            command: "list-targets"
        )

        XCTAssertEqual(result.exitCode, 0, "list-targets should succeed")
        XCTAssertFalse(result.stdout.isEmpty, "list-targets should produce output")

        // Compare against golden file
        GoldenFileManager.assertMatchesGolden(result: result, name: "list-targets")
    }

    func testListGroupsCommand() {
        let result = CLITestHarness.executeWithProject(
            testProjectPath,
            command: "list-groups"
        )

        XCTAssertEqual(result.exitCode, 0, "list-groups should succeed")
        XCTAssertFalse(result.stdout.isEmpty, "list-groups should produce output")

        // Compare against golden file
        GoldenFileManager.assertMatchesGolden(result: result, name: "list-groups")
    }

    func testListFilesCommand() {
        let result = CLITestHarness.executeWithProject(
            testProjectPath,
            command: "list-files"
        )

        XCTAssertEqual(result.exitCode, 0, "list-files should succeed")
        XCTAssertFalse(result.stdout.isEmpty, "list-files should produce output")

        // Compare against golden file
        GoldenFileManager.assertMatchesGolden(result: result, name: "list-files")
    }

    func testListTreeCommand() {
        let result = CLITestHarness.executeWithProject(
            testProjectPath,
            command: "list-tree"
        )

        XCTAssertEqual(result.exitCode, 0, "list-tree should succeed")
        XCTAssertFalse(result.stdout.isEmpty, "list-tree should produce output")

        // Compare against golden file
        GoldenFileManager.assertMatchesGolden(result: result, name: "list-tree")
    }

    func testListBuildConfigsCommand() {
        let result = CLITestHarness.executeWithProject(
            testProjectPath,
            command: "list-build-configs"
        )

        XCTAssertEqual(result.exitCode, 0, "list-build-configs should succeed")
        XCTAssertFalse(result.stdout.isEmpty, "list-build-configs should produce output")

        // Compare against golden file
        GoldenFileManager.assertMatchesGolden(result: result, name: "list-build-configs")
    }

    func testListSwiftPackagesCommand() {
        let result = CLITestHarness.executeWithProject(
            testProjectPath,
            command: "list-swift-packages"
        )

        XCTAssertEqual(result.exitCode, 0, "list-swift-packages should succeed")

        // Compare against golden file
        GoldenFileManager.assertMatchesGolden(result: result, name: "list-swift-packages")
    }

    func testListSchemesCommand() {
        let result = CLITestHarness.executeWithProject(
            testProjectPath,
            command: "list-schemes"
        )

        XCTAssertEqual(result.exitCode, 0, "list-schemes should succeed")

        // Compare against golden file
        GoldenFileManager.assertMatchesGolden(result: result, name: "list-schemes")
    }

    func testListInvalidReferencesCommand() {
        let result = CLITestHarness.executeWithProject(
            testProjectPath,
            command: "list-invalid-references"
        )

        XCTAssertEqual(result.exitCode, 0, "list-invalid-references should succeed")

        // Compare against golden file
        GoldenFileManager.assertMatchesGolden(result: result, name: "list-invalid-references")
    }

    // MARK: - Help Text Tests

    func testMainHelp() {
        let result = CLITestHarness.executeCommand(["--help"])

        XCTAssertEqual(result.exitCode, 0, "--help should succeed")
        XCTAssertFalse(result.stdout.isEmpty, "--help should produce output")

        // Compare against golden file
        GoldenFileManager.assertMatchesGolden(result: result, name: "main-help", category: "help")
    }

    func testVersionInfo() {
        let result = CLITestHarness.executeCommand(["--version"])

        XCTAssertEqual(result.exitCode, 0, "--version should succeed")
        XCTAssertFalse(result.stdout.isEmpty, "--version should produce output")

        // Compare against golden file
        GoldenFileManager.assertMatchesGolden(result: result, name: "version-info", category: "help")
    }

    // MARK: - Error Scenarios

    func testMissingProjectFile() {
        let result = CLITestHarness.executeCommand([
            "--project", "/nonexistent/project.xcodeproj",
            "validate"
        ])

        XCTAssertNotEqual(result.exitCode, 0, "Should fail with missing project")
        // Error message may be in stdout or stderr
        XCTAssertTrue(
            !result.stdout.isEmpty || !result.stderr.isEmpty,
            "Should produce error message"
        )

        // Compare against golden file (error goes to stdout, not stderr)
        GoldenFileManager.assertMatchesGolden(
            result: result,
            name: "project-not-found",
            category: "errors"
        )
    }

    func testValidateProductsCommand() {
        let result = CLITestHarness.executeWithProject(
            testProjectPath,
            command: "validate-products"
        )

        XCTAssertEqual(result.exitCode, 0, "validate-products should succeed")
        XCTAssertFalse(result.stdout.isEmpty, "validate-products should produce output")

        GoldenFileManager.assertMatchesGolden(result: result, name: "validate-products")
    }

    func testListBuildSettingsCommand() {
        let result = CLITestHarness.executeWithProject(
            testProjectPath,
            command: "list-build-settings"
        )

        XCTAssertEqual(result.exitCode, 0, "list-build-settings should succeed")
        XCTAssertFalse(result.stdout.isEmpty, "list-build-settings should produce output")

        GoldenFileManager.assertMatchesGolden(result: result, name: "list-build-settings")
    }

    func testGetBuildSettingsCommand() {
        let result = CLITestHarness.executeWithProject(
            testProjectPath,
            command: "get-build-settings",
            args: ["TestApp"]
        )

        XCTAssertEqual(result.exitCode, 0, "get-build-settings should succeed")
        XCTAssertFalse(result.stdout.isEmpty, "get-build-settings should produce output")

        GoldenFileManager.assertMatchesGolden(result: result, name: "get-build-settings")
    }

    func testListWorkspaceProjectsCommand() {
        // Note: This command requires a workspace file, which our test project doesn't have
        // It should handle this gracefully by reporting an error or empty result
        let result = CLITestHarness.executeWithProject(
            testProjectPath,
            command: "list-workspace-projects"
        )

        // Command should execute without crashing, even if no workspace exists
        // Output may be in stdout or stderr
        XCTAssertTrue(
            !result.stdout.isEmpty || !result.stderr.isEmpty,
            "list-workspace-projects should produce output (error message or results)"
        )

        GoldenFileManager.assertMatchesGolden(result: result, name: "list-workspace-projects")
    }

    // MARK: - TODO: Additional Commands
    // Remaining 40 commands need golden files from actual execution or help text only:
    // - File Commands: add-file, add-files, add-folder, add-sync-folder, remove-file, move-file
    // - Target Commands: add-target, duplicate-target, remove-target, add-dependency, add-target-file, remove-target-file
    // - Build Commands: set-build-setting, add-build-phase
    // - Framework Commands: add-framework
    // - Package Commands: add-swift-package, remove-swift-package, update-swift-packages
    // - Group Commands: create-groups, remove-group
    // - Path Commands: update-paths, update-paths-map
    // - Product Commands: repair-product-references, add-product-reference, repair-project, repair-targets
    // - Scheme Commands: create-scheme, duplicate-scheme, remove-scheme, set-scheme-config, add-scheme-target, enable-test-coverage, set-test-parallel
    // - Workspace Commands: create-workspace, add-project-to-workspace, remove-project-from-workspace, list-workspace-projects, add-project-reference, add-cross-project-dependency
    // - Inspection Commands: remove-invalid-references
}
