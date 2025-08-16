# Changelog

All notable changes to xcodeproj-cli will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.2.1] - 2025-08-16

### Improved
- **Help Command**: The `-h`/`--help` command now displays ALL 47 available commands organized by category
  - Makes it much more useful for AI coding agents and users who need a complete command reference
  - Commands are clearly grouped: Files, Targets, Groups, Build, Packages, Schemes, Workspaces, etc.
  - Previously only showed a subset of "common" commands
- **Dynamic Help Generation**: Help text is now dynamically generated from command registry
  - Eliminates manual synchronization when adding new commands
  - Help always reflects actual available commands
  - Commands automatically appear in correct category
  - Reduces maintenance burden and prevents stale documentation

## [2.2.0] - 2025-08-16

### Fixed
- **Critical: Duplicate PBXBuildFile crash** - Fixed fatal crash when removing files with duplicate build file entries
  - Replaced `Set<PBXBuildFile>` with `Array<PBXBuildFile>` to avoid XcodeProj 9.4.3 Hashable implementation bug
  - Added identity comparison for reliable duplicate detection
  - Ensures batch file removal operations complete successfully even with corrupted project files
- **Folder removal crash** - Fixed inconsistent pattern in `removeFolderReference` that could cause crashes

### Improved
- **Error Handling**: `BuildPhaseManager.addFileToBuildPhases` now returns missing targets instead of silently failing
- **Null Safety**: Build phase files arrays are initialized if nil before appending to prevent silent failures
- **Code Quality**: Extracted duplicate detection logic into reusable `addUniqueByIdentity()` utility method
- **Performance**: Implemented `ObjectIdentifier` tracking for O(1) duplicate detection in large projects
- **Test Coverage**: Added comprehensive tests for duplicate build file scenarios

## [2.1.0] - 2025-08-15

### Added
- **Target File Management**: New commands for managing file-to-target associations without modifying project structure
  - `add-target-file` - Add existing project files to additional targets' compile sources or resources
  - `remove-target-file` - Remove files from specific targets while keeping them in the project
  - Both commands support multiple targets via `--targets` flag for batch operations
- **Target Filtering for Inspection Commands**: Enhanced list commands with target-specific filtering
  - `list-files --target <name>` - List files in a specific target
  - `list-tree --target <name>` - Show project tree filtered by target membership
- **Command-Specific Help System**: Individual command help via `--help` flag
  - Use `xcodeproj-cli <command> --help` or `-h` to get detailed usage for any command
  - Works without requiring a project file to be present
  - All 45+ commands have comprehensive help documentation with examples

### Improved
- **File Path Flexibility**: All file-related commands now support flexible path matching
  - Filename only: `Model.swift` matches any file with that name
  - Partial path: `Sources/Model.swift` matches files with that path segment
  - Full project path: Complete path within the project structure
- **Documentation**: Updated README with clearer explanations of file path handling

## [2.0.0] - 2025-08-12

### ⚠️ BREAKING CHANGES
- **Removed Swift script version** - xcodeproj-cli is now distributed exclusively as a compiled binary
- **Installation changed** - Script-based installation is no longer supported; use Homebrew or binary installation
- **File structure changed** - Source code moved from `src/xcodeproj-cli.swift` to `Sources/xcodeproj-cli/main.swift`

### Added
- **Modular Architecture**: Complete refactoring into 55+ specialized modules with clear separation of concerns
- **Performance Optimizations**: Multi-level intelligent caching system with O(1) lookups for groups, targets, and file references
- **Security Enhancements**: Comprehensive input validation, path sanitization, and command injection prevention
- **Verbose Mode**: `--verbose` flag provides detailed operation timing, cache statistics, and performance metrics
- **Enhanced Test Suites**: 136+ tests using Swift Package Manager, including security-focused tests, integration tests, and performance validation
- **Core Services**: Transaction management, project validation, cache management, and build phase management
- **Performance Profiling**: Built-in performance monitoring with timing reports and memory usage tracking
- **Scheme Management**: Complete suite of 8 commands for creating, configuring, and managing Xcode schemes
- **Workspace Support**: Full workspace management with 6 new commands for multi-project setups
- **Cross-Project Dependencies**: Support for linking targets across different projects
- **Build Configuration Management**: Advanced .xcconfig file support with diff, copy, and export features
- **Localization Support**: Manage project localizations and variant groups for internationalization
- Swift Package Manager configuration (`Package.swift`)
- Universal binary build support (Intel + Apple Silicon)
- GitHub Actions workflow for automated releases
- Pre-built binary distribution via GitHub Releases
- Homebrew tap support for easy installation
- ARCHITECTURE.md documentation for developers

### New Commands (35+ commands added)
#### Scheme Management
- `create-scheme` - Create new schemes for targets
- `duplicate-scheme` - Clone existing schemes
- `remove-scheme` - Delete schemes
- `list-schemes` - List all project schemes
- `set-scheme-config` - Configure scheme build settings
- `add-scheme-target` - Add targets to scheme build actions
- `enable-test-coverage` - Enable code coverage in schemes
- `set-test-parallel` - Configure test parallelization

#### Workspace Management
- `create-workspace` - Create new Xcode workspaces
- `add-project-to-workspace` - Add projects to workspaces
- `remove-project-from-workspace` - Remove projects from workspaces
- `list-workspace-projects` - List all workspace projects
- `add-project-reference` - Add external project references
- `add-cross-project-dependency` - Create cross-project target dependencies

### Changed
- **Architecture Refactoring**: Migrated from single-file script to modular, service-oriented architecture
- **Performance Improvements**: Dramatic performance gains through intelligent caching and optimized operations
- **Build System**: Migrated from Swift script to compiled binary for better performance
- **Installation Method**: Simplified installation to Homebrew-only approach
- **Runtime Dependencies**: Removed dependency on swift-sh for end users
- **Startup Performance**: Improved startup performance (no dependency resolution at runtime)
- **Error Handling**: Enhanced error messages with actionable remediation steps
- **Memory Management**: Optimized memory usage with lazy initialization and automatic cleanup

### Removed
- Swift script version (`src/xcodeproj-cli.swift`)
- Script installation option from install.sh
- Runtime dependency on swift-sh

### Migration Guide
If you were using the Swift script version (v1.x), you'll need to:
1. Uninstall the old script version
2. Install v2.0.0 via Homebrew: `brew tap tolo/xcodeproj && brew install xcodeproj-cli`
3. The tool is now available as `xcodeproj-cli` (not `xcodeproj-cli.swift`)

### Technical Notes
- **Complete Architecture Overhaul**: Migrated from single 1200+ line script to modular architecture with 55+ specialized Swift files
- **Service-Oriented Design**: Implemented service layer with dedicated managers for caching, transactions, validation, and build phases
- **Command Pattern**: Each CLI operation is now a discrete, testable command class
- **Performance Analytics**: Built-in performance profiling with cache hit/miss statistics and operation timing
- **Enhanced Security**: Comprehensive input validation and security utilities throughout the codebase
- **Test Coverage**: Expanded from basic tests to comprehensive test suites including security and integration tests
- Full backward compatibility maintained for all CLI commands and flags

## [1.1.0] - 2025-08-11

### Added
- `list-tree` command - Display complete project structure as a tree with filesystem paths for actual files/folders
- `add-group` command - Create empty virtual groups (renamed from `create-groups`)
- `list-build-settings` command - Enhanced Xcode-style display of build settings with multiple output formats
  - Setting-centric view (like Xcode) showing values across configurations
  - `--json`/`-j` flag for JSON output suitable for automation
  - `--all`/`-a` flag to display all project and target settings at once
  - `--show-inherited`/`-i` flag to include inherited settings from project level
  - `--target`/`-t` flag for consistency with other commands
  - `--config`/`-c` flag to filter by specific configuration
  - Inline display for uniform values, expanded view for configuration-specific values
  - JSON output uses setting-centric structure for easier parsing
  - Clear inheritance tracking showing which settings override project values
- `remove-invalid-references` command - Automatically clean up broken file and folder references
- Enhanced test coverage for invalid references operations
- Improved test coverage for group operations
- Auto discovery of project file in current directory

### Changed
- `list-groups` command now uses tree-style formatting with box-drawing characters (├──, └──, │)
- `list-tree` intelligently shows paths only for actual file/folder references, not virtual groups
- `create-groups` command renamed to `add-group` for consistency
- `remove-folder` command deprecated in favor of `remove-group` (handles all group types)
- Improved documentation for groups vs folders vs file references
- Enhanced README with clearer explanations of Xcode project organization
- Promoted `list-tree` as the recommended command for viewing project structure
- Improved error handling consistency across all commands (exit codes)
- Enhanced error messages to include available options (e.g., list of valid targets)

### Fixed
- Invalid folder references detection and removal
- Test suite compatibility improvements
- JSON error responses now properly structured with error details
- Eliminated code duplication in build settings display logic (~150 lines reduced)
- Fixed force unwrapping risks in configuration handling

## [1.0.0] - 2025-08-09

### 🎉 Initial Release

A powerful command-line utility for programmatically manipulating Xcode project files (.xcodeproj) without requiring Xcode or Docker.

### ✨ Core Features

#### 30+ Commands for Complete Project Manipulation
- **File Operations**: `add-file`, `add-files`, `add-folder`, `add-sync-folder`, `move-file`, `remove-file`
- **Target Management**: `add-target`, `duplicate-target`, `remove-target`, `list-targets`
- **Build Configuration**: `set-build-setting`, `get-build-settings`, `list-build-configs`
- **Dependencies**: `add-framework`, `add-dependency`, `add-swift-package`, `remove-swift-package`, `list-swift-packages`
- **Project Structure**: `create-groups`, `list-groups`, `list-files`, `validate`
- **Diagnostics**: `list-invalid-references` - Identifies invalid file and directory references

#### Smart File Handling
- **Automatic filtering** of system files (.DS_Store, .git, .bak, etc.)
- **Recursive folder scanning** with intelligent file type detection (20+ types supported)
- **Automatic build phase assignment** (sources vs resources)
- **Synchronized folder references** for dynamic content

#### Named Arguments CLI
- Clean, modern CLI with named arguments for better usability
- `--project` flag for working with any .xcodeproj file
- `-p` shorthand support
- `--dry-run` mode to preview changes without saving
- Clear, actionable error messages

### 🔒 Security Features
- **Path traversal protection** - Sanitizes file paths to prevent directory escaping
- **Command injection prevention** - Escapes shell metacharacters in build scripts
- **Input validation** - Validates package versions, URLs, and paths
- **Atomic file operations** - Automatic backup/restore on failures

### 🧪 Testing & Quality
- **Comprehensive test suite** with 25+ test cases
- **SwiftUI-based test data** for realistic testing scenarios
- **Security test suite** validating input sanitization
- **Swift test infrastructure** using modern testing patterns

### 📝 Developer Experience
- **Fast execution** via direct swift-sh script
- **Transaction support** with automatic rollback on failures
- **Extensive documentation** with real-world examples
- **Simple installation** via curl-based installer

### 📦 Requirements
- Swift 5.0+
- macOS 10.15+
- swift-sh (installed automatically)
- XcodeProj library v9.4.3+ (managed via swift-sh)

### 🚀 Installation
```bash
curl -fsSL https://raw.githubusercontent.com/tolo/xcodeproj-cli/main/install.sh | bash
```

### 📖 Documentation
- Comprehensive README with all commands
- Details -h and --help flags for usage
