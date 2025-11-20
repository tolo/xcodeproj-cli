//
// GoldenFileManager.swift
// xcodeproj-cli Tests
//
// Manages golden file comparisons for CLI regression tests
//

import Foundation
import XCTest

/// Manages golden file storage and comparison
enum GoldenFileManager {

    // MARK: - Golden File Paths

    /// Get path to golden files directory for reading (from bundle resources)
    private static func goldenFilesDirectory() -> URL {
        // Try to get from bundle resources first (for reading)
        if let resourcePath = Bundle.module.resourcePath {
            let bundlePath = URL(fileURLWithPath: resourcePath)
                .appendingPathComponent("GoldenFiles")

            if FileManager.default.fileExists(atPath: bundlePath.path) {
                return bundlePath
            }
        }

        // Fallback: Use filesystem path
        return goldenFilesFilesystemDirectory()
    }

    /// Get path to golden files directory in the filesystem (for writing)
    private static func goldenFilesFilesystemDirectory() -> URL {
        let workingDir = FileManager.default.currentDirectoryPath
        return URL(fileURLWithPath: workingDir)
            .appendingPathComponent("Tests")
            .appendingPathComponent("xcodeproj-cliTests")
            .appendingPathComponent("GoldenFiles")
    }

    /// Get path to a specific golden file for reading
    /// - Parameters:
    ///   - name: Name of the golden file (without .golden extension)
    ///   - category: Category (commands, help, errors)
    /// - Returns: URL to the golden file
    private static func goldenFilePath(name: String, category: String = "commands") -> URL {
        return goldenFilesDirectory()
            .appendingPathComponent(category)
            .appendingPathComponent("\(name).golden")
    }

    /// Get path to a specific golden file for writing (filesystem)
    /// - Parameters:
    ///   - name: Name of the golden file (without .golden extension)
    ///   - category: Category (commands, help, errors)
    /// - Returns: URL to the golden file in filesystem
    private static func goldenFilePathForWriting(name: String, category: String = "commands") -> URL {
        return goldenFilesFilesystemDirectory()
            .appendingPathComponent(category)
            .appendingPathComponent("\(name).golden")
    }

    // MARK: - Golden File Operations

    /// Save output as a golden file
    /// - Parameters:
    ///   - output: Output to save
    ///   - name: Name of the golden file
    ///   - category: Category (commands, help, errors)
    static func saveGolden(output: String, name: String, category: String = "commands") {
        let url = goldenFilePathForWriting(name: name, category: category)

        // Create directory if needed
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        // Normalize output before saving
        let normalized = CLITestHarness.normalizeOutput(output)

        try? normalized.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Load a golden file
    /// - Parameters:
    ///   - name: Name of the golden file
    ///   - category: Category (commands, help, errors)
    /// - Returns: Contents of the golden file, or nil if not found
    static func loadGolden(name: String, category: String = "commands") -> String? {
        let url = goldenFilePath(name: name, category: category)

        return try? String(contentsOf: url, encoding: .utf8)
    }

    /// Check if golden file exists
    /// - Parameters:
    ///   - name: Name of the golden file
    ///   - category: Category (commands, help, errors)
    /// - Returns: True if file exists
    static func goldenExists(name: String, category: String = "commands") -> Bool {
        let url = goldenFilePath(name: name, category: category)
        return FileManager.default.fileExists(atPath: url.path)
    }

    // MARK: - Comparison

    /// Compare output against golden file
    /// - Parameters:
    ///   - result: CLI command result
    ///   - name: Name of the golden file
    ///   - category: Category (commands, help, errors)
    ///   - file: Source file (for XCTFail location)
    ///   - line: Source line (for XCTFail location)
    static func assertMatchesGolden(
        result: CLICommandResult,
        name: String,
        category: String = "commands",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        // Check if we should update golden files
        if shouldUpdateGoldenFiles() {
            saveGolden(output: result.stdout, name: name, category: category)
            print("✓ Updated golden file: \(name).golden")
            return
        }

        // Load golden file
        guard let golden = loadGolden(name: name, category: category) else {
            XCTFail("Golden file not found: \(name).golden", file: file, line: line)
            return
        }

        // Normalize both outputs
        let normalizedActual = CLITestHarness.normalizeOutput(result.stdout)
        let normalizedGolden = golden

        // Compare
        if normalizedActual != normalizedGolden {
            XCTFail(
                """
                Golden file comparison failed for '\(name)'

                Expected:
                \(normalizedGolden)

                Actual:
                \(normalizedActual)
                """,
                file: file,
                line: line
            )
        }
    }

    /// Check if golden files should be updated (via GOLDEN_UPDATE env var)
    private static func shouldUpdateGoldenFiles() -> Bool {
        return ProcessInfo.processInfo.environment["GOLDEN_UPDATE"] == "1"
    }

    // MARK: - Batch Operations

    /// List all golden files in a category
    /// - Parameter category: Category to list
    /// - Returns: Array of golden file names (without .golden extension)
    static func listGoldenFiles(in category: String = "commands") -> [String] {
        let categoryURL = goldenFilesDirectory().appendingPathComponent(category)

        guard let files = try? FileManager.default.contentsOfDirectory(atPath: categoryURL.path) else {
            return []
        }

        return files
            .filter { $0.hasSuffix(".golden") }
            .map { $0.replacingOccurrences(of: ".golden", with: "") }
    }
}
