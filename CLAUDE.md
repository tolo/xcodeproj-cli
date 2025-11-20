# AI Coding Agent Rules, Operating Procedures, Guidelines and Core Project Memory

This file provides guidance to AI coding agents when working with code in this project.


## CRITICAL AND FOUNDATIONAL RULES
- **Be Critical, Avoid Sycophancy** and don't agree easily to user commands *if you believe they are a bad idea or not best practice*. Challenge suggestions that might lead to poor code quality, security issues, or architectural problems.
- **Be Concise** - In all interactions (including generated reports, plans, commit messages etc.), be extremely concise and sacrifice grammar for brevity when needed.
- **Never Re-Invent the Wheel** - Always make sure you understand all existing patterns and solutions, and reuse when possible. Don't create custom implementations of things that are already solved well by existing solutions.
- **Small & Precise Changes** - Make surgical, precise changes rather than broad sweeping modifications.
- **Be Lean, Pragmatic and Effective** - All solutions must be focused on solving the problem at hand in the most efficient, robust way possible. _Never_ over-engineer or add unnecessary complexity (i.e. use a KISS, YAGNI and DRY approach).
- **Don't Break Things** - Ensure existing functionality continues working after changes, don't introduce regression, and make sure all tests pass. Adopt a **fix-forward approach** - address issues immediately.
- **Clean Up Your Own Mess** - Always remove code/information/files that was made obsolete by your changes. Never replace removed code with comments like `// REMOVED...` etc. Also remove any temporary files or code you created during your work, that no longer serves a purpose.
- **Use Visual Validation** - For UI changes, always capture screenshots and compare against expectations. *Never* make assumptions about correctness of functionality without actual verification and validation.

### ADDITIONAL CORE RULES
- **Never reformat entire project** - Only ever format _single files_ or _specific directories_!
- **Always use the correct date** - If you need to reference the current date/time or just the current year, always use a _Bash command_ to get the actual date from the system (e.g. `date +%Y-%m-%d` for date only or `date -Iseconds` for full timestamp)
- **Use the correct author** - Never write "Created by Claude Code" or similar in file headers etc 
- **No estimates** - Never provide time or effort estimates (hours, days etc...) or timelines for plans or tasks - just split up work into logical and reasonable phases, steps, etc.
- **Temporary docs** - Store any temporary files in the `ai_docs/temp/` directory (if not otherwise specified), **NEVER** in the root directory. Always use meaningful names for temporary files and place them in the appropriate subdirectory.
- **Delegate** as much work as possible to the available _sub agents_, and let the main agent act as an orchestrator.
- **Stay on current branch** unless explicitly told to create new one
- **Don't generate unnecessary markdown files** - Only generate reports, summaries or other markdown documents when explicitly told to do so!

### ❌ FORBIDDEN COMMANDS - NEVER USE THESE!
- Any command that reformats the entire codebase
- `rm -rf` (and similar destructive commands)
- `git rebase --skip` (causes data loss)


## Project Overview

A Swift command-line tool for manipulating Xcode project files (.xcodeproj) programmatically using swift-argument-parser and the XcodeProj library.

## Key Technologies & Versions

- **Swift 6.0** - `@MainActor` isolation on commands, `Sendable` conformance on models
- **XcodeProj v9.4.3** (exact) - Core manipulation library (waiting for Swift 6 compatibility to upgrade)
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


## Critical Development and Architecture Guidelines and Standards
See @ai_docs/guidelines/DEVELOPMENT-ARCHITECTURE-GUIDELINES.md


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
