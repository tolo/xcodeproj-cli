# AI Coding Agent Rules, Operating Procedures, Guidelines and Core Project Memory

This file provides guidance to AI coding agents when working with code in this project.


--- 


## Project Overview

A Swift command-line tool for manipulating Xcode project files (.xcodeproj) programmatically using swift-argument-parser and the XcodeProj library.

## Key Technologies & Versions

- **Swift 6.0** - `@MainActor` isolation on commands, `Sendable` conformance on models
- **XcodeProj v9.7.2+** - Core manipulation library
- **PathKit v1.0.0+** - Uses `@preconcurrency` import until Swift 6 adoption
- **swift-argument-parser v1.5.0+** - `AsyncParsableCommand` pattern
- **macOS 10.15+** minimum

## Project Structure (Essential)

```
xcodeproj-cli/
├── Sources/xcodeproj-cli/          # Main implementation
├── Tests/xcodeproj-cliTests/       # Test suite
├── Package.swift                   # SPM configuration
├── build-universal.sh              # Universal binary build
└── .github/workflows/              # CI/CD automation
```

## Core Components (Quick Reference)

- **XcodeProjCLI** - Main ArgumentParser command structure
- **ProjectServiceFactory** - Service initialization from global options
- **GlobalOptions** - Shared CLI options (--project, --verbose, --dry-run)
- **ProjectServices** - Service coordination container
- **Services** - FileService, TargetService, GroupService, PackageService, BuildSettingsService
- **XcodeProjUtility** - Coordination layer
- **CacheManager** - Performance optimization
- **TransactionService** - Safe operations with backup/rollback
- **ValidationService** - Integrity checking

**📋 For detailed architecture information, see [ARCHITECTURE.md](./ARCHITECTURE.md)**

**See README.md for full command documentation.**


--- 


## Workflow Rules, Guardrails and Guidelines

### Foundational Rules and Guardrails
_Always fully read and understand this file before doing any work:_ @ai_docs/rules/CRITICAL-RULES-AND-GUARDRAILS.md


### Foundational Development Guidelines and Standards
Always fully read relevant guidelines below as needed, based on the type of work being done:
- _`ai_docs/guidelines/DEVELOPMENT-ARCHITECTURE-GUIDELINES.md`_ when doing development work (coding, architecture, etc.)
- _`ai_docs/guidelines/UX-UI-GUIDELINES.md`_ when doing UX/UI related work
- _`ai_docs/guidelines/WEB-DEV-GUIDELINES.md`_ when doing web development work


---


## Project Specific Development Philosophy

### Code Style
- Use Swift naming conventions (PascalCase for types, camelCase for methods)
- Prefer structs over classes for data models
- Prefer guard statements for early returns
- Use swift-format (v601.0.0+) for consistent formatting

### Error Handling
- Use custom `ProjectError` enum for domain-specific errors
- Provide actionable error messages with specific remediation steps
- Fail fast with clear error reporting
- Exit with meaningful codes (0 = success, 1 = error, specific codes for specific failures)

### Testing Philosophy
- Test suite uses real project manipulation (not mocks)
- Tests are organized by feature area
- Each test should be independent and restorable
- Always verify both positive and negative cases

### Documentation Guidelines
- Never document code that is self-explanatory
- Never write full API-level documentation for application code
- For complex or non-obvious code, add concise comments explaining the purpose and logic (but only when needed)

### **KNOWN DESIGN DECISIONS (Don't Second-Guess)**
- **Single `..` in paths is allowed** - This is intentional for parent directory access
- **XcodeProjUtility remains large** - Gradual migration planned, see ROADMAP.md
- **Binary-only distribution** - Swift script removed in v2.0.0, this is permanent
- **Homebrew as primary distribution** - Optimized for this installation method
- **No mocking in tests** - Real project manipulation is intentional for authenticity


## Testing and Code Analysis Guidelines

### Code Analysis and Style (Analysis, Linting and Formatting)

**IMPORTANT**: Only run formatting/linting commands after modifying Swift source or test code, and preferably only on the specific files that were changed.

```bash
# Swift code formatting on specific modified files (preferred)
swift-format format --in-place path/to/ModifiedFile.swift

# Swift code linting on specific modified files (preferred)
swift-format lint path/to/ModifiedFile.swift

# Format multiple specific files
swift-format format --in-place Sources/xcodeproj-cli/Services/FileService.swift Tests/xcodeproj-cliTests/FileOperationsTests.swift

# Only if you modified many files across a directory, format recursively
swift-format format --in-place --recursive Sources/xcodeproj-cli/Services
swift-format lint --recursive Sources/xcodeproj-cli/Services
```

### Running Tests

All tests use Swift Package Manager and are located in `Tests/xcodeproj-cliTests/`.

```bash
# Run all tests
swift test

# Run specific test suite
swift test --filter ValidationTests    # Read-only validation tests
swift test --filter FileOperationsTests # File manipulation tests
swift test --filter BuildAndTargetTests # Target and build tests
swift test --filter PackageTests        # Swift package tests
swift test --filter SecurityTests       # Security tests

# Run with verbose output
swift test --verbose

# Run with code coverage
swift test --enable-code-coverage

# Run tests in parallel
swift test --parallel
```

### Test Categories

The test suite is organized across 17 test files:

- **ValidationTests** - Read-only operations that don't modify projects
- **FileOperationsTests** - File and folder manipulation
- **TargetFileOperationsTests** - Target-specific file operations
- **BuildAndTargetTests** - Target management and build settings
- **BuildConfigurationTests** - Build configuration management
- **PackageTests** - Swift Package Manager integration
- **IntegrationTests** - Complex multi-command workflows
- **ComprehensiveTests** - Full feature coverage
- **SecurityTests** - Path traversal and injection protection
- **BasicTests** - Core CLI functionality
- **AdditionalTests** - Edge cases and error handling
- **ProductReferenceTests** - Product reference handling
- **ProductCommandIntegrationTests** - Product command integration
- **SchemeTests** - Scheme management
- **WorkspaceTests** - Workspace operations
- **PathUtilsTests** - Path utilities
- **GroupHandlingTests** - Group handling operations

### Adding New Tests

1. Add test methods to appropriate test file in `Tests/xcodeproj-cliTests/`
2. Use XCTest assertions (`XCTAssertEqual`, `XCTAssertTrue`, etc.)
3. Use `TestHelpers` for common operations
4. Ensure tests are independent and restorable
5. Test both success and failure cases


## Common Tasks

### Adding a New Command

Commands use swift-argument-parser's `AsyncParsableCommand` pattern:

1. Create command struct conforming to `AsyncParsableCommand` in `ArgumentParser/Commands/{Category}/`
2. Add to subcommands array in `XcodeProjCLI.swift:16`
3. Implement `@MainActor func run() async throws` with proper error handling
4. Define arguments/options using `@Argument`, `@Option`, `@Flag` property wrappers
5. Use `@OptionGroup var global: GlobalOptions` for shared options (--project, --verbose, --dry-run)
6. Add help documentation using `CommandConfiguration` (abstract, discussion, usage)
7. Use `ProjectServiceFactory.createServices(from: global)` to initialize services
8. Validate inputs and call appropriate service methods
9. Add test coverage in appropriate test file in `Tests/xcodeproj-cliTests/`
10. Document in README.md if adding major functionality

Example command structure:
```swift
@MainActor
struct MyCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "my-command",
    abstract: "Brief description"
  )

  @OptionGroup var global: GlobalOptions
  @Argument var someArg: String
  @Option var someOption: String?

  func run() async throws {
    let services = try ProjectServiceFactory.createServices(from: global)
    // Implementation
    try services.save()
  }
}
```

### Debugging Issues
- Use `print()` statements for debug output
- Check `.xcodeproj/project.pbxproj` directly for state
- Use `validate` command to check project integrity
- Test with backup projects to avoid data loss
- Look for orphaned file references or missing build files
- Verify group hierarchy matches file system structure

## Performance & Troubleshooting

**Performance**: File operations batched, multi-level caching (O(1) lookups), tested with 1000+ file projects.
See [ARCHITECTURE.md](./ARCHITECTURE.md) for details.

**Common Issues**:
- XcodeProj dependency errors: `rm -rf .build && swift build -c release`
- Project corruption: Restore from `.xcodeproj.backup` (automatic backups)
- Use `validate` command to identify problems

## Key Resources

- [XcodeProj Library](https://github.com/tuist/XcodeProj) - Core manipulation library
- [swift-argument-parser](https://github.com/apple/swift-argument-parser) - CLI framework
- [Xcode Build Settings Reference](https://developer.apple.com/documentation/xcode/build-settings-reference)

## Release Preparation

**Checklist**: See [homebrew/PUBLISHING_CHECKLIST.md](./homebrew/PUBLISHING_CHECKLIST.md)

**Version files to update:**
- `XcodeProjCLI.swift:15`, `CHANGELOG.md`, `ARCHITECTURE.md:3`

## Project Documentation

- **[ARCHITECTURE.md](./ARCHITECTURE.md)** - Detailed system design, patterns, migration strategy
- **[ROADMAP.md](./ROADMAP.md)** - Planned features and design decisions
- **[CHANGELOG.md](./CHANGELOG.md)** - Version history
- **[README.md](./README.md)** - User-facing documentation and command reference
