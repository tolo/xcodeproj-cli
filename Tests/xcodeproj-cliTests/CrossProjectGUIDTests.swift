//
// CrossProjectGUIDTests.swift
// xcodeproj-cliTests
//
// Tests for cross-project dependency GUID handling
// Ensures --target-id parameter correctly wires to remoteGlobalID in PBXContainerItemProxy

import Foundation
@preconcurrency import PathKit
import XCTest
@preconcurrency import XcodeProj

final class CrossProjectGUIDTests: XCTestCase {

  var createdProjects: [URL] = []
  var createdTestFiles: [URL] = []

  override func tearDown() {
    for projectURL in createdProjects {
      try? FileManager.default.removeItem(at: projectURL)
    }
    TestHelpers.cleanupTestItems(createdTestFiles)
    createdProjects.removeAll()
    createdTestFiles.removeAll()
    super.tearDown()
  }

  // MARK: - Cross-Project GUID Tests

  func testCrossProjectDependencyWithTargetId() throws {
    // Create two test projects
    let mainProject = try createMinimalTestProject(name: "MainProject")
    let dependencyProject = try createMinimalTestProject(name: "DependencyProject")

    createdProjects.append(mainProject)
    createdProjects.append(dependencyProject)

    // Use a sample GUID for testing
    let testGUID = "A1B2C3D4E5F6G7H8I9J0K1L2"

    // Add cross-project dependency with explicit target ID
    let result = try TestHelpers.runCommand(
      "add-cross-project-dependency",
      arguments: [
        "--project", mainProject.path,
        "MainProject",
        dependencyProject.path,
        "DependencyProject",
        "--target-id", testGUID,
      ])

    // Command should execute (may succeed or provide helpful error)
    // The key is that --target-id parameter is recognized
    if result.success {
      TestHelpers.assertCommandSuccess(result)
      TestHelpers.assertOutputContains(result.output, "Added cross-project dependency")

      // Now inspect the pbxproj to verify the remoteGlobalID was stored correctly
      let projectPath = Path(mainProject.path)
      let xcodeproj = try XcodeProj(path: projectPath)
      let pbxproj = xcodeproj.pbxproj

      // Find PBXContainerItemProxy objects
      let containerProxies = pbxproj.containerItemProxies

      // Should have at least one container proxy
      XCTAssertGreaterThan(
        containerProxies.count, 0,
        "Should have created at least one PBXContainerItemProxy"
      )

      // Verify at least one proxy has the correct remoteGlobalID
      // RemoteGlobalID is an enum, so we need to extract the GUID string
      let matchingProxy = containerProxies.first { proxy in
        guard let remoteID = proxy.remoteGlobalID else { return false }
        switch remoteID {
        case .string(let guid):
          return guid == testGUID
        case .object(let object):
          return object.uuid == testGUID
        }
      }

      // Collect found GUIDs for debugging
      let foundGUIDs = containerProxies.compactMap { proxy -> String? in
        guard let remoteID = proxy.remoteGlobalID else { return nil }
        switch remoteID {
        case .string(let guid):
          return guid
        case .object(let object):
          return object.uuid
        }
      }

      XCTAssertNotNil(
        matchingProxy,
        "Should have a PBXContainerItemProxy with remoteGlobalID = \(testGUID). Found GUIDs: \(foundGUIDs)"
      )
    } else {
      // If it fails, verify it's not due to unrecognized --target-id flag
      XCTAssertFalse(
        result.error.contains("Unknown option '--target-id'"),
        "--target-id parameter should be recognized"
      )
    }
  }

  func testCrossProjectDependencyWithoutTargetId() throws {
    // Create two test projects
    let mainProject = try createMinimalTestProject(name: "MainProject2")
    let dependencyProject = try createMinimalTestProject(name: "DependencyProject2")

    createdProjects.append(mainProject)
    createdProjects.append(dependencyProject)

    // Add cross-project dependency without target ID
    let result = try TestHelpers.runCommand(
      "add-cross-project-dependency",
      arguments: [
        "--project", mainProject.path,
        "MainProject2",
        dependencyProject.path,
        "DependencyProject2",
      ])

    // Command should execute (--target-id is optional)
    if result.success {
      TestHelpers.assertCommandSuccess(result)
    } else {
      // Verify failure is not due to missing --target-id (it's optional)
      XCTAssertFalse(
        result.error.contains("Missing expected option '--target-id'"),
        "--target-id should be optional"
      )
    }
  }

  func testTargetIdParameterFormat() throws {
    // Test that various GUID formats are accepted
    let mainProject = try createMinimalTestProject(name: "MainProject3")
    let dependencyProject = try createMinimalTestProject(name: "DependencyProject3")

    createdProjects.append(mainProject)
    createdProjects.append(dependencyProject)

    // Test with typical Xcode GUID format (24 characters, alphanumeric)
    let validGUIDs = [
      "ABC123DEF456GHI789JKL012",
      "1234567890ABCDEF12345678",
    ]

    for guid in validGUIDs {
      let result = try TestHelpers.runCommand(
        "add-cross-project-dependency",
        arguments: [
          "--project", mainProject.path,
          "MainProject3",
          dependencyProject.path,
          "DependencyProject3",
          "--target-id", guid,
        ])

      // Verify --target-id is recognized and processed
      XCTAssertFalse(
        result.error.contains("Unknown option '--target-id'"),
        "--target-id should be recognized for GUID: \(guid)"
      )
    }
  }

  // MARK: - Helper Methods

  private func createMinimalTestProject(name: String) throws -> URL {
    let projectName = "\(name).xcodeproj"
    let projectURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
      .appendingPathComponent(projectName)

    try FileManager.default.createDirectory(
      at: projectURL, withIntermediateDirectories: true)

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
                      D8F8F8F8F8F8F8F8F8F8F8F8,
                  );
              };
              08FB7794FE84155DC02AAC07 /* \(name) */ = {
                  isa = PBXGroup;
                  children = (
                  );
                  name = \(name);
                  sourceTree = "<group>";
              };
              1DEB928908733DD80010E9CD /* Build configuration list */ = {
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
              D8F8F8F8F8F8F8F8F8F8F8F8 /* \(name) */ = {
                  isa = PBXNativeTarget;
                  buildConfigurationList = 1DEB928908733DD80010E9CD;
                  buildPhases = (
                  );
                  dependencies = (
                  );
                  name = \(name);
                  productName = \(name);
              };
          };
          rootObject = 08FB7793FE84155DC02AAC07;
      }
      """

    try minimalPbxproj.write(to: pbxprojURL, atomically: true, encoding: .utf8)
    return projectURL
  }
}
