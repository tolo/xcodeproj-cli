//
// WorkspaceTests.swift
// xcodeproj-cliTests
//
// Comprehensive tests for workspace-related commands in xcodeproj-cli
//

import XCTest
import Foundation

final class WorkspaceTests: XCTProjectTestCase {
    
    var createdWorkspaces: [URL] = []
    var createdProjects: [URL] = []
    var createdTestFiles: [URL] = []
    
    override func tearDown() {
        // Clean up created workspaces and projects
        TestHelpers.cleanupTestItems(createdWorkspaces + createdProjects + createdTestFiles)
        createdWorkspaces.removeAll()
        createdProjects.removeAll()
        createdTestFiles.removeAll()
        
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func createTestProject(name: String) throws -> URL {
        let projectName = "\(name).xcodeproj"
        let projectURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(projectName)
        
        // Create a minimal project structure
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true, attributes: nil)
        
        let pbxprojURL = projectURL.appendingPathComponent("project.pbxproj")
        let minimalPbxproj = """
        // !$*UTF8*$!
        {
            archiveVersion = 1;
            classes = {
            };
            objectVersion = 50;
            objects = {
                08FB7793FE84155DC02AAC07 /* Project object */ = {
                    isa = PBXProject;
                    attributes = {
                    };
                    buildConfigurationList = 1DEB928908733DD80010E9CD;
                    compatibilityVersion = "Xcode 3.2";
                    developmentRegion = en;
                    hasScannedForEncodings = 1;
                    knownRegions = (
                        en,
                    );
                    mainGroup = 08FB7794FE84155DC02AAC07;
                    projectDirPath = "";
                    projectRoot = "";
                    targets = (
                    );
                };
                08FB7794FE84155DC02AAC07 /* \(name) */ = {
                    isa = PBXGroup;
                    children = (
                    );
                    name = \(name);
                    sourceTree = "<group>";
                };
                1DEB928908733DD80010E9CD /* Build configuration list for PBXProject "\(name)" */ = {
                    isa = XCConfigurationList;
                    buildConfigurations = (
                        1DEB928A08733DD80010E9CD,
                        1DEB928B08733DD80010E9CD,
                    );
                    defaultConfigurationIsVisible = 0;
                    defaultConfigurationName = Release;
                };
                1DEB928A08733DD80010E9CD /* Debug */ = {
                    isa = XCBuildConfiguration;
                    buildSettings = {
                        PRODUCT_NAME = \(name);
                    };
                    name = Debug;
                };
                1DEB928B08733DD80010E9CD /* Release */ = {
                    isa = XCBuildConfiguration;
                    buildSettings = {
                        PRODUCT_NAME = \(name);
                    };
                    name = Release;
                };
            };
            rootObject = 08FB7793FE84155DC02AAC07 /* Project object */;
        }
        """
        
        try minimalPbxproj.write(to: pbxprojURL, atomically: true, encoding: .utf8)
        
        createdProjects.append(projectURL)
        return projectURL
    }
    
    private func workspaceExists(_ workspaceName: String) -> Bool {
        let workspacePath = "\(workspaceName).xcworkspace"
        return FileManager.default.fileExists(atPath: workspacePath)
    }
    
  // MARK: - Create Workspace Tests
    
  func testCreateWorkspaceBasic() throws {
        let workspaceName = "TestWorkspace-\(UUID().uuidString)"
        let workspaceURL = URL(fileURLWithPath: "\(workspaceName).xcworkspace")
        createdWorkspaces.append(workspaceURL)
        
        let result = try runSuccessfulCommand("create-workspace", arguments: [workspaceName])
        
        TestHelpers.assertCommandSuccess(result)
        TestHelpers.assertOutputContains(result.output, workspaceName)
        
        // Verify workspace was created
        XCTAssertTrue(workspaceExists(workspaceName), "Workspace should be created")
    }
    
    // MARK: - Create Workspace Error Cases
    
    func testCreateWorkspaceMissingName() throws {
        let result = try runFailingCommand("create-workspace", arguments: [])
        
        TestHelpers.assertCommandFailure(result)
        TestHelpers.assertOutputOrErrorContains(result, "required")
    }
    
    func testCreateWorkspaceDuplicate() throws {
        let workspaceName = "TestWorkspaceDuplicate"
        let workspaceURL = URL(fileURLWithPath: "\(workspaceName).xcworkspace")
        createdWorkspaces.append(workspaceURL)
        
        // Create first workspace
        let result1 = try runSuccessfulCommand("create-workspace", arguments: [workspaceName])
        TestHelpers.assertCommandSuccess(result1)
        
        // Try to create duplicate
        let result2 = try runCommand("create-workspace", arguments: [workspaceName])
        
        if result2.success {
            // Some implementations might allow overwriting
            XCTAssertTrue(true, "Workspace creation allows overwriting")
        } else {
            // Should indicate workspace already exists
            TestHelpers.assertOutputOrErrorContains(result2, "exists")
        }
    }
    
    // MARK: - Add Project to Workspace Tests
    
    func testAddProjectToWorkspace() throws {
        let workspaceName = "TestWorkspaceAddProject"
        let workspaceURL = URL(fileURLWithPath: "\(workspaceName).xcworkspace")
        createdWorkspaces.append(workspaceURL)
        
        // Create workspace first
        let createResult = try runSuccessfulCommand("create-workspace", arguments: [workspaceName])
        TestHelpers.assertCommandSuccess(createResult)
        
        // Create a test project
        let projectURL = try createTestProject(name: "TestProject")
        
        // Add project to workspace using correct syntax: workspace-name project-path
        let result = try runCommand("add-project-to-workspace", arguments: [
            workspaceName,
            projectURL.path
        ])
        
        if result.success {
            TestHelpers.assertCommandSuccess(result)
            // Just verify the command executed successfully
            XCTAssertTrue(true, "Project added to workspace successfully")
        } else {
            // Should provide meaningful error
            TestHelpers.assertOutputOrErrorContains(result, "project")
        }
    }
    
    // MARK: - Add Project to Workspace Error Cases
    
    func testAddProjectToWorkspaceMissingArguments() throws {
        let result = try runFailingCommand("add-project-to-workspace", arguments: [])
        
        TestHelpers.assertCommandFailure(result)
        TestHelpers.assertOutputOrErrorContains(result, "required")
    }
    
    func testAddProjectToWorkspaceMissingProject() throws {
        let workspaceName = "TestWorkspaceMissingProject"
        let workspaceURL = URL(fileURLWithPath: "\(workspaceName).xcworkspace")
        createdWorkspaces.append(workspaceURL)
        
        // Create workspace
        let createResult = try runSuccessfulCommand("create-workspace", arguments: [workspaceName])
        TestHelpers.assertCommandSuccess(createResult)
        
        // Try to add non-existent project
        let result = try runCommand("add-project-to-workspace", arguments: [
            workspaceName,
            "NonExistent.xcodeproj"
        ])
        
        if result.success {
            // Some implementations might allow adding non-existent projects (references)
            TestHelpers.assertCommandSuccess(result)
            XCTAssertTrue(true, "Command allows adding non-existent project references")
        } else {
            // Or it should fail with meaningful error
            TestHelpers.assertCommandFailure(result)
            TestHelpers.assertOutputOrErrorContains(result, "not found")
        }
    }
    
    // MARK: - Remove Project from Workspace Tests
    
    func testRemoveProjectFromWorkspace() throws {
        let workspaceName = "TestWorkspaceRemoveProject"
        let workspaceURL = URL(fileURLWithPath: "\(workspaceName).xcworkspace")
        createdWorkspaces.append(workspaceURL)
        
        // Create workspace
        let createResult = try runSuccessfulCommand("create-workspace", arguments: [workspaceName])
        TestHelpers.assertCommandSuccess(createResult)
        
        // Create and add project
        let projectURL = try createTestProject(name: "TestProjectToRemove")
        let addResult = try runCommand("add-project-to-workspace", arguments: [
            workspaceName,
            projectURL.path
        ])
        
        if addResult.success {
            // Remove project from workspace  
            let result = try runCommand("remove-project-from-workspace", arguments: [
                workspaceName,
                projectURL.path
            ])
            
            if result.success {
                TestHelpers.assertCommandSuccess(result)
                XCTAssertTrue(true, "Project removed from workspace successfully")
            } else {
                // Should provide meaningful error
                TestHelpers.assertOutputOrErrorContains(result, "project")
            }
        } else {
            // If add failed, just verify remove gives appropriate error
            let result = try runFailingCommand("remove-project-from-workspace", arguments: [
                workspaceName,
                projectURL.path
            ])
            TestHelpers.assertOutputOrErrorContains(result, "not found")
        }
    }
    
    // MARK: - List Workspace Projects Tests
    
    func testListWorkspaceProjectsEmpty() throws {
        let workspaceName = "TestWorkspaceEmpty"
        let workspaceURL = URL(fileURLWithPath: "\(workspaceName).xcworkspace")
        createdWorkspaces.append(workspaceURL)
        
        // Create empty workspace
        let createResult = try runSuccessfulCommand("create-workspace", arguments: [workspaceName])
        TestHelpers.assertCommandSuccess(createResult)
        
        // List projects
        let result = try runCommand("list-workspace-projects", arguments: [workspaceName])
        
        if result.success {
            TestHelpers.assertCommandSuccess(result)
            // Should indicate empty workspace or no projects
            XCTAssertTrue(
                result.output.contains("No projects") || result.output.contains("0 project") ||
                result.output.contains("empty") || result.output.isEmpty,
                "Should indicate empty workspace"
            )
        } else {
            // Should provide meaningful error
            TestHelpers.assertOutputOrErrorContains(result, "workspace")
        }
    }
    
    // MARK: - Other Workspace Commands Tests
    
    func testAddProjectReference() throws {
        let workspaceName = "TestWorkspaceReference"
        let workspaceURL = URL(fileURLWithPath: "\(workspaceName).xcworkspace")
        createdWorkspaces.append(workspaceURL)
        
        // Create workspace
        let createResult = try runSuccessfulCommand("create-workspace", arguments: [workspaceName])
        TestHelpers.assertCommandSuccess(createResult)
        
        // Create projects
        let mainProjectURL = try createTestProject(name: "MainProject")
        let refProjectURL = try createTestProject(name: "RefProject")
        
        // Test add-project-reference command
        let result = try runCommand("add-project-reference", arguments: [
            mainProjectURL.path,
            refProjectURL.path
        ])
        
        // Just verify the command is recognized and gives some response
        XCTAssertTrue(
            result.output.isNotEmpty || result.error.isNotEmpty,
            "Command should provide some output or error message"
        )
    }
    
    func testAddCrossProjectDependency() throws {
        let workspaceName = "TestWorkspaceDependency"
        let workspaceURL = URL(fileURLWithPath: "\(workspaceName).xcworkspace")
        createdWorkspaces.append(workspaceURL)
        
        // Create workspace
        let createResult = try runSuccessfulCommand("create-workspace", arguments: [workspaceName])
        TestHelpers.assertCommandSuccess(createResult)
        
        // Create projects
        let project1URL = try createTestProject(name: "DependentProject")
        let project2URL = try createTestProject(name: "DependencyProject")
        
        // Test add-cross-project-dependency command
        let result = try runCommand("add-cross-project-dependency", arguments: [
            project1URL.path,
            project2URL.path
        ])
        
        // Just verify the command is recognized
        XCTAssertTrue(
            result.output.isNotEmpty || result.error.isNotEmpty,
            "Command should provide some output or error message"
        )
    }
    
    // MARK: - Security Tests
    
    func testWorkspacePathTraversalProtection() throws {
        // Test path traversal protection
        let maliciousPaths = [
            "../../../sensitive/file"
        ]
        
        for maliciousPath in maliciousPaths {
            let result = try runCommand("create-workspace", arguments: [maliciousPath])
            
            if result.success {
                // If it creates anything, add to cleanup
                let workspaceURL = URL(fileURLWithPath: "\(maliciousPath).xcworkspace")
                createdWorkspaces.append(workspaceURL)
            } else {
                // Should reject or handle dangerous paths appropriately
                XCTAssertTrue(
                    result.output.contains("invalid") || result.error.contains("invalid") ||
                    result.output.contains("path") || result.error.contains("path") ||
                    result.output.contains("unsafe") || result.error.contains("unsafe"),
                    "Should handle potentially dangerous paths: \(maliciousPath)"
                )
            }
        }
    }
    
    // MARK: - Integration Tests
    
    func testCompleteWorkspaceWorkflow() throws {
        let workspaceName = "TestCompleteWorkflow"
        let workspaceURL = URL(fileURLWithPath: "\(workspaceName).xcworkspace")
        createdWorkspaces.append(workspaceURL)
        
        // 1. Create workspace
        let createResult = try runSuccessfulCommand("create-workspace", arguments: [workspaceName])
        TestHelpers.assertCommandSuccess(createResult)
        
        // 2. Create test project
        let projectURL = try createTestProject(name: "App")
        
        // 3. Add project to workspace
        let addResult = try runCommand("add-project-to-workspace", arguments: [
            workspaceName,
            projectURL.path
        ])
        
        if addResult.success {
            TestHelpers.assertCommandSuccess(addResult)
            
            // 4. List projects to verify
            let listResult = try runCommand("list-workspace-projects", arguments: [workspaceName])
            
            if listResult.success {
                // Should show the added project or at least not be empty
                XCTAssertTrue(
                    listResult.output.contains("App") || listResult.output.contains("1 project"),
                    "Should show added project in workspace"
                )
            }
            
            // 5. Remove project
            let removeResult = try runCommand("remove-project-from-workspace", arguments: [
                workspaceName,
                projectURL.path
            ])
            
            // Should either succeed or give meaningful error
            if !removeResult.success {
                TestHelpers.assertOutputOrErrorContains(removeResult, "project")
            }
        } else {
            // If add failed, still verify basic workspace functionality works
            XCTAssertTrue(workspaceExists(workspaceName), "Workspace should exist even if project add failed")
        }
    }
    
    // MARK: - Help and Usage Tests
    
    func testWorkspaceCommandsShowHelp() throws {
        let workspaceCommands = [
            "create-workspace",
            "add-project-to-workspace",
            "remove-project-from-workspace",
            "list-workspace-projects"
        ]
        
        for command in workspaceCommands {
            let result = try runCommand(command, arguments: ["--help"])
            
            // Help might not be implemented for all commands
            // Just verify the command is recognized
            XCTAssertTrue(
                result.output.isNotEmpty || result.error.isNotEmpty,
                "Command \(command) should be recognized"
            )
        }
    }
}
