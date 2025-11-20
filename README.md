# XcodeProj CLI

A powerful command-line utility for manipulating Xcode project files (.xcodeproj) without requiring Xcode or Docker. Designed for both **human developers** and **AI coding assistants** to automate Xcode project management.

## Acknowledgments

This tool is built on top of the excellent [XcodeProj](https://github.com/tuist/XcodeProj) library by the Tuist team, which provides the core functionality for reading and writing Xcode project files.

The tool's comprehensive feature set was inspired by [xcodeproj-mcp-server](https://github.com/giginet/xcodeproj-mcp-server) by giginet, reimplemented as a standalone Swift script for easier deployment and use.

## Why This Tool?

### 🤖 AI-Agent Friendly
- **Simple CLI interface** - Easy for LLMs to understand and use
- **Clear error messages** - Helps agents self-correct
- **Dry-run mode** - Agents can preview changes before applying
- **Predictable behavior** - Consistent outputs for reliable automation

### 👨‍💻 Developer Friendly
- **No Xcode required** - Works on any macOS system
- **Script-friendly** - Perfect for CI/CD pipelines
- **Fast execution** - Direct Swift implementation
- **Comprehensive commands** - Cover all common project operations

## Features

### 🎯 Complete Project Manipulation
- **File Management** - Add, remove, move files and folders
- **Target Management** - Create, duplicate, remove targets
- **Build Configuration** - Modify build settings and configurations
- **Dependencies** - Manage frameworks and target dependencies
- **Swift Packages** - Add/remove SPM dependencies with version validation
- **Build Phases** - Add run scripts and copy files phases
- **Group Management** - Create and organize project groups
- **Product Reference Management** - Validate and repair product references and Products group
- **Scheme Management** - Create, configure, and manage Xcode schemes
- **Workspace Support** - Create workspaces and manage multi-project setups
- **Cross-Project Dependencies** - Link targets across different projects
- **Build Configuration Management** - Advanced .xcconfig file support
- **Localization Support** - Manage localizations and variant groups

### ✨ Smart Features
- **Modern CLI** - Built with swift-argument-parser for type-safe, auto-generated help
- **Recursive folder scanning** with intelligent file filtering
- **Automatic build phase assignment** (sources vs resources)
- **File type detection** for 20+ file types
- **Batch operations** for efficiency
- **Comprehensive validation** and error handling
- **Dry-run mode** - Preview changes before applying
- **Atomic saves** - Automatic backup and rollback on failure
- **Transaction support** - Group operations with rollback capability
- **Performance optimizations** - Intelligent caching system with cache hit/miss statistics
- **Verbose mode** - Detailed operation insights with `--verbose` flag
- **Modular architecture** - Service-oriented design with focused responsibilities

### 🔒 Security Features
- **Path traversal protection** - Prevents directory escaping
- **Command injection prevention** - Escapes shell metacharacters
- **Input validation** - Validates versions, URLs, and paths
- **Safe file operations** - Atomic writes with automatic backup

## Installation

### Prerequisites
- macOS 10.15+ (Catalina or later)
- Swift 6.0+ (for building from source)
- No additional dependencies required

### Installation

#### Homebrew (Recommended) 🍺
Fastest installation with pre-built universal binary. No dependencies required!

```bash
# Add the tap
brew tap tolo/xcodeproj

# Install the tool
brew install xcodeproj-cli

# Upgrade to latest version
brew upgrade tolo/xcodeproj/xcodeproj-cli
```

The tool will be available as `xcodeproj-cli` in your PATH:
```bash
xcodeproj-cli --help
xcodeproj-cli --project MyApp.xcodeproj list-targets
```

#### Manual Binary Install
Download pre-built binary from releases:

1. Download the latest release:
```bash
curl -L "https://github.com/tolo/xcodeproj-cli/releases/latest/download/xcodeproj-cli-$(curl -s https://api.github.com/repos/tolo/xcodeproj-cli/releases/latest | grep 'tag_name' | cut -d'"' -f4)-macos.tar.gz" -o xcodeproj-cli.tar.gz
```

2. Extract and install:
```bash
tar -xzf xcodeproj-cli.tar.gz
sudo mv xcodeproj-cli /usr/local/bin/
chmod +x /usr/local/bin/xcodeproj-cli
```


#### Build from Source
For development or custom builds:

**Requirements**: Swift 6.0+ toolchain

```bash
git clone https://github.com/tolo/xcodeproj-cli.git
cd xcodeproj-cli

# Build with Swift Package Manager
swift build -c release
.build/release/xcodeproj-cli --help

# Or build universal binary
./build-universal.sh
./xcodeproj-cli --help
```


## Usage

### Getting Started

#### Command Syntax & Options
```bash
xcodeproj-cli [options] <command> [arguments]

# Specify project (default: looks for *.xcodeproj in current directory)
xcodeproj-cli --project MyApp.xcodeproj <command>

# Preview changes without saving (dry-run mode)
xcodeproj-cli --dry-run <command>

# Enable verbose output with performance metrics
xcodeproj-cli --verbose <command>

# Combine options
xcodeproj-cli --project App.xcodeproj --dry-run --verbose add-file File.swift --group Group --targets Target

# Many flags have short forms for convenience:
# --group / -g, --targets / -t, --recursive / -r, --verbose / -V
xcodeproj-cli add-file Helper.swift -g Utils -t MyApp -V

# Get help for any command
xcodeproj-cli <command> --help
xcodeproj-cli add-file --help
```

### Common Workflows

#### 📁 Working with Files and Folders

**Adding Files**
```bash
# Add a single file to a group and target
xcodeproj-cli add-file Sources/Helper.swift --group Utils --targets MyApp

# Add multiple files at once
xcodeproj-cli add-files \
  Model.swift:Models \
  View.swift:Views \
  Controller.swift:Controllers \
  --targets MyApp
```

**Adding Folders**
```bash
# Add all files from a folder recursively (files are added individually)
xcodeproj-cli add-folder Sources/Features --group Features --targets MyApp --recursive

# Add a synchronized folder (Xcode 16+ - auto-syncs with filesystem)
xcodeproj-cli add-sync-folder Resources/Assets --group Assets --targets MyApp
```

**Managing Files**
```bash
# Move or rename a file
xcodeproj-cli move-file OldPath/File.swift NewPath/File.swift

# Remove a file from the project
xcodeproj-cli remove-file Sources/Deprecated.swift

# Remove an entire folder
xcodeproj-cli remove-folder Resources/OldAssets
```

#### 🗂️ Working with Groups (Virtual Organization)

```bash
# Create groups for organizing files (no filesystem folders created)
xcodeproj-cli create-groups UI/Components UI/Screens Services/API  # alias: add-group

# Show complete project structure (RECOMMENDED)
xcodeproj-cli list-tree

# List groups only in tree format (no files)
xcodeproj-cli list-groups
# Output:
# MyProject
# ├── Sources
# ├── Resources
# └── Features
#     ├── Login
#     └── Profile

# Remove a group (files remain in project)
xcodeproj-cli remove-group UI/OldComponents
```

#### 🎯 Target Management

```bash
# Create a new target
xcodeproj-cli add-target MyFramework --type com.apple.product-type.framework --bundle-id com.example.framework

# Duplicate an existing target
xcodeproj-cli duplicate-target MyApp MyAppPro --bundle-id com.example.pro

# Remove a target
xcodeproj-cli remove-target OldTarget

# Add dependency between targets
xcodeproj-cli add-dependency MyApp --depends-on MyFramework

# List all targets
xcodeproj-cli list-targets
```

#### ⚙️ Build Settings & Configuration

```bash
# Set a build setting for specific targets
xcodeproj-cli set-build-setting SWIFT_VERSION 5.9 --targets MyApp,MyAppTests

# Get build settings for a target
xcodeproj-cli get-build-settings MyApp --config Debug

# List all build configurations
xcodeproj-cli list-build-configs --target MyApp
```

#### 📦 Dependencies & Frameworks

**System Frameworks**
```bash
# Add a system framework
xcodeproj-cli add-framework CoreData --target MyApp

# Add and embed a custom framework
xcodeproj-cli add-framework Custom.framework --target MyApp --embed
```

**Swift Package Manager**
```bash
# Add package with version requirement
xcodeproj-cli add-swift-package \
  https://github.com/Alamofire/Alamofire \
  --requirement "from: 5.8.0" \
  --target MyApp

# Add package from branch
xcodeproj-cli add-swift-package \
  https://github.com/realm/SwiftLint \
  --requirement "branch: main" \
  --target MyApp

# Remove a package
xcodeproj-cli remove-swift-package https://github.com/Alamofire/Alamofire

# List all packages
xcodeproj-cli list-swift-packages
```

#### 🔧 Build Phases

```bash
# Add a run script phase
xcodeproj-cli add-build-phase run_script \
  --name "SwiftLint" --target MyApp \
  --script "if which swiftlint; then swiftlint; fi"

# Add a copy files phase
xcodeproj-cli add-build-phase copy_files --name "Copy Fonts" --target MyApp
```

#### 🔍 Project Inspection & Validation

```bash
# Validate project integrity
xcodeproj-cli validate

# List and clean up invalid file references
xcodeproj-cli list-invalid-references
xcodeproj-cli remove-invalid-references

# Show complete project structure (recommended)
# Virtual groups shown without paths, actual files/folders with paths
xcodeproj-cli list-tree
# Output example:
# MyProject
# ├── Sources              <- Virtual group (no path)
# │   ├── Models           <- Virtual group
# │   │   └── User.swift (Sources/Models/User.swift)
# │   └── Views            <- Virtual group  
# │       └── MainView.swift (UI/Views/MainView.swift)
# └── Resources            <- Virtual group
#     └── Assets.xcassets (Resources/Assets.xcassets)
```

## Understanding Xcode Project Organization

### Groups vs Folders vs Files - What's the Difference?

Xcode has three distinct ways to organize and reference files in your project:

#### 1️⃣ **Groups** - Virtual Organization Only
- **What**: Virtual containers that only exist in the `.xcodeproj` file
- **Icon**: Yellow folder icon in Xcode
- **Filesystem**: NO actual folders created on disk
- **Use When**: You want to organize files in Xcode differently than on disk
- **Commands**: `create-groups` (alias: `add-group`), `remove-group` (removes any group type)

```bash
# Create virtual organization structure
xcodeproj-cli create-groups UI/Components UI/Screens  # alias: add-group

# Files can be in any disk location but appear organized in Xcode
xcodeproj-cli add-file random/path/Button.swift --group UI/Components --targets MyApp
```

#### 2️⃣ **Folder References** - Live Filesystem Sync
- **What**: References to actual filesystem folders that auto-sync
- **Icon**: Blue folder icon in Xcode 16+ 
- **Filesystem**: Directly linked to a real folder - changes auto-reflect
- **Use When**: Resources/assets that change frequently outside Xcode
- **Commands**: `add-sync-folder` (creates synced folders), `remove-group` (removes them)

```bash
# Creates a synchronized folder reference (Xcode 16+)
xcodeproj-cli add-sync-folder Resources/Images --group Images --targets MyApp
# Any files added to Resources/Images on disk automatically appear in Xcode
```

#### 3️⃣ **Regular File/Folder Addition** - Individual File References
- **What**: Creates a group and adds files from a folder as individual references
- **Icon**: Yellow folder group containing individual file icons in Xcode
- **Filesystem**: Each file is tracked separately, group mirrors folder structure
- **Use When**: Source code where you want control over what's included
- **Commands**: `add-folder` (creates group from folder), `remove-group` (removes it)

```bash
# Adds each file from the folder individually
xcodeproj-cli add-folder Sources/Features --group Features --targets MyApp --recursive
# You control exactly which files are included
```

### Common Scenarios Explained

**Scenario 1: Organizing existing files**
```bash
# Just create groups - no need to move files on disk
xcodeproj-cli create-groups Architecture/MVVM/Models Architecture/MVVM/Views  # alias: add-group
xcodeproj-cli add-file Sources/User.swift --group Architecture/MVVM/Models --targets MyApp
```

**Scenario 2: Adding a folder of source files**
```bash
# No groups needed - they're created automatically
xcodeproj-cli add-folder Sources/NewFeature --group Features --targets MyApp --recursive
```

**Scenario 3: Adding frequently-changing resources**
```bash
# Use sync folder for assets that designers update
xcodeproj-cli add-sync-folder Design/Assets --group Resources --targets MyApp
```


## For AI Coding Assistants

If you're an AI coding assistant (Claude Code, GitHub Copilot, etc.), here are key points:

### Quick Start
```bash
# Always specify the project file
xcodeproj-cli --project App.xcodeproj <command>

# Test your command first with dry-run
xcodeproj-cli --dry-run --project App.xcodeproj add-file Helper.swift --group Utils --targets App

# Common operations
add-file File.swift --group Group --targets Target  # Add single file
add-folder /path/to/folder --group Group --targets Target --recursive  # Add entire folder
list-targets                          # See available targets
validate                              # Check project health
```

### Best Practices
1. **Always use `--project`** to specify the exact .xcodeproj file
2. **Use `--dry-run`** first to preview changes
3. **Use `--verbose`** to monitor performance and see detailed operation insights
4. **Use `--help`** to see detailed command usage: `xcodeproj-cli <command> --help`
5. **Check available targets** with `list-targets` before adding files
6. **Use `list-groups`** to see the project structure
7. **Run `validate`** after bulk operations

### Path Handling
- Relative paths (e.g., `Sources/Helper.swift`) are preferred for project files
- Absolute paths (e.g., `/Users/dev/libs/SDK.framework`) work for external dependencies
- Single `../` is allowed for parent directory references
- Home directory `~/` expansion is supported

## Real-World Examples

### Setting Up a New Feature Module

```bash
# Create the folder structure
xcodeproj-cli create-groups \
  Features/UserProfile \
  Features/UserProfile/Models \
  Features/UserProfile/Views \
  Features/UserProfile/ViewModels

# Add all files from your feature folder
xcodeproj-cli add-folder \
  Sources/UserProfile \
  --group Features/UserProfile \
  --targets MyApp,MyAppTests \
  --recursive

# Add required dependencies
xcodeproj-cli add-swift-package \
  https://github.com/firebase/firebase-ios-sdk \
  --requirement "from: 10.0.0" \
  --target MyApp
```

### Creating Multiple App Variants

```bash
# Create Pro and Lite versions of your app
xcodeproj-cli duplicate-target MyApp MyAppPro --bundle-id com.example.pro
xcodeproj-cli duplicate-target MyApp MyAppLite --bundle-id com.example.lite

# Configure different build settings for each variant
xcodeproj-cli set-build-setting PRODUCT_NAME "MyApp Pro" --targets MyAppPro
xcodeproj-cli set-build-setting ENABLE_PREMIUM_FEATURES YES --targets MyAppPro
xcodeproj-cli set-build-setting ENABLE_ADS YES --targets MyAppLite
```

### Adding CI/CD Build Phases

```bash
# Add SwiftLint
xcodeproj-cli add-build-phase \
  run_script \
  --name "SwiftLint" \
  --target MyApp \
  --script 'if which swiftlint > /dev/null; then
  swiftlint
else
  echo "warning: SwiftLint not installed"
fi'

# Add automatic build number increment
xcodeproj-cli add-build-phase \
  run_script \
  --name "Increment Build Number" \
  --target MyApp \
  --script 'buildNumber=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "${PROJECT_DIR}/${INFOPLIST_FILE}")
buildNumber=$((buildNumber + 1))
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $buildNumber" "${PROJECT_DIR}/${INFOPLIST_FILE}"'
```

### Batch Import Script

```bash
#!/bin/bash
# Import all Swift files from a directory while preserving structure
find Sources -name "*.swift" | while read file; do
  group=$(dirname "$file" | sed 's/Sources\//Classes\//')
  xcodeproj-cli add-file "$file" --group "$group" --targets MyApp
done
```

## Command Reference

### 📂 Project Inspection
| Command | Description | Example |
|---------|-------------|---------|
| `list-tree` | **Show complete project tree** (recommended) | `list-tree` |
| `list-tree` | Show target's files as tree | `list-tree --target TargetName` |
| `list-targets` | Show all targets in project | `list-targets` |
| `list-files` | Show files only (flat list) | `list-files [group-name]` |
| `list-files` | List files in specific target | `list-files --target TargetName` |
| `list-groups` | Show groups in tree format (no files) | `list-groups` |
| `validate` | Check project integrity | `validate` |
| `list-invalid-references` | Find broken file references | `list-invalid-references` |
| `remove-invalid-references` | Clean up broken references | `remove-invalid-references` |

### 🏷️ Product Reference Management
| Command | Description | Example |
|---------|-------------|---------|
| `validate-products` | Check product references and Products group | `validate-products --fix` |
| `repair-product-references` | Fix missing product references | `repair-product-references --targets MyApp,MyFramework` |
| `add-product-reference` | Manually add product reference | `add-product-reference MyFramework --type com.apple.product-type.framework` |
| `repair-project` | Comprehensive project repair | `repair-project` |
| `repair-targets` | Repair target configuration | `repair-targets MyApp` |

### 🗂️ Group Management
| Command | Description | Example |
|---------|-------------|---------|  
| `create-groups` (alias: `add-group`) | Add empty virtual groups | `create-groups UI/Components Services/API` |
| `remove-group` | Remove any group/folder type | `remove-group OldGroup` |

### 📁 File & Folder Management

> **Note**: File paths can be specified as: filename only (`Model.swift`), partial path (`Sources/Model.swift`), or full project path

| Command | Description | Example |
|---------|-------------|---------|
| `add-file` | Add single file | `add-file Path/File.swift --group GroupName --targets Target1,Target2` |
| `add-files` | Add multiple files | `add-files file1:group1 file2:group2 --targets Target` |
| `add-folder` | Create group from folder contents | `add-folder Path/Folder --group GroupName --targets Target --recursive` |
| `add-sync-folder` | Add synced folder reference (Xcode 16+) | `add-sync-folder Path/Assets --group GroupName --targets Target` |
| `move-file` | Move or rename file | `move-file old/path new/path` |
| `remove-file` | Remove file from project | `remove-file Path/File.swift` |
| `remove-folder` | (Deprecated - use `remove-group`) | `remove-group Path/Folder` |
| `add-target-file` | Add existing file to targets | `add-target-file File.swift --targets Target1,Target2` |
| `remove-target-file` | Remove file from targets only | `remove-target-file File.swift --targets Target1,Target2` |

### 🎯 Target Operations
| Command | Description | Example |
|---------|-------------|---------|
| `add-target` | Create new target | `add-target MyKit --type com.apple.product-type.framework --bundle-id com.example.kit` |
| `duplicate-target` | Clone existing target | `duplicate-target MyApp MyAppPro --bundle-id com.example.pro` |
| `remove-target` | Delete target | `remove-target OldTarget` |
| `add-dependency` | Link targets | `add-dependency AppTarget --depends-on FrameworkTarget` |

### ⚙️ Build Settings
| Command | Description | Example |
|---------|-------------|---------|
| `set-build-setting` | Modify build setting | `set-build-setting SWIFT_VERSION 5.9 --targets MyApp,Tests` |
| `get-build-settings` | View build settings | `get-build-settings MyApp --config Debug` |
| `list-build-configs` | Show configurations | `list-build-configs --target MyApp` |

### 📦 Dependencies & Packages
| Command | Description | Example |
|---------|-------------|---------|
| `add-framework` | Add framework | `add-framework CoreData --target MyApp` |
| `add-framework` | Embed framework | `add-framework Custom.framework --target MyApp --embed` |
| `add-swift-package` | Add Swift package | `add-swift-package https://github.com/pkg --requirement "from: 1.0.0" --target MyApp` |
| `remove-swift-package` | Remove package | `remove-swift-package https://github.com/pkg` |
| `list-swift-packages` | Show all packages | `list-swift-packages` |

### 🔨 Build Phases
| Command | Description | Example |
|---------|-------------|---------|
| `add-build-phase` | Add run script | `add-build-phase run_script --name "SwiftLint" --target MyApp --script "swiftlint"` |
| `add-build-phase` | Add copy files | `add-build-phase copy_files --name "Copy Resources" --target MyApp` |

### 🎨 Scheme Management
| Command | Description | Example |
|---------|-------------|---------|
| `create-scheme` | Create new scheme | `create-scheme MyApp --target MyApp --shared` |
| `duplicate-scheme` | Clone existing scheme | `duplicate-scheme Production Staging` |
| `remove-scheme` | Delete scheme | `remove-scheme OldScheme` |
| `list-schemes` | Show all schemes | `list-schemes --shared` |
| `set-scheme-config` | Set build configurations | `set-scheme-config MyApp --run Debug --archive Release` |
| `add-scheme-target` | Add target to scheme | `add-scheme-target MyApp MyFramework --action build,test` |
| `enable-test-coverage` | Enable code coverage | `enable-test-coverage MyApp --targets Core,UI` |
| `set-test-parallel` | Configure test parallelization | `set-test-parallel MyApp --enable` |

### 🏗️ Workspace Management
| Command | Description | Example |
|---------|-------------|---------|
| `create-workspace` | Create new workspace | `create-workspace MyWorkspace` |
| `add-project-to-workspace` | Add project to workspace | `add-project-to-workspace MyWorkspace App/App.xcodeproj` |
| `remove-project-from-workspace` | Remove project from workspace | `remove-project-from-workspace MyWorkspace App.xcodeproj` |
| `list-workspace-projects` | List workspace projects | `list-workspace-projects MyWorkspace` |
| `add-project-reference` | Add external project reference | `add-project-reference ../Library/Library.xcodeproj --group Dependencies` |
| `add-cross-project-dependency` | Add cross-project dependency | `add-cross-project-dependency MyApp ../Lib/Lib.xcodeproj LibTarget` |


## File Filtering

The tool automatically excludes certain files when adding folders:

### Excluded Files
- `.DS_Store`
- `.git`, `.gitignore`, `.gitkeep`
- `Thumbs.db`
- Files starting with `.` (except `.h` and `.m`)
- Files ending with `.orig`, `.bak`, `.tmp`, `.temp`

## Supported File Types

The tool recognizes and properly categorizes:

- **Source Files**: `.swift`, `.m`, `.mm`, `.cpp`, `.cc`, `.cxx`, `.c`, `.h`, `.hpp`
- **Interface Files**: `.xib`, `.storyboard`
- **Resources**: `.xcassets`, `.strings`, `.plist`, `.json`
- **Media**: `.png`, `.jpg`, `.jpeg`, `.gif`, `.mp3`, `.wav`, `.mp4`, `.mov`
- **Frameworks**: `.framework`, `.dylib`, `.a`

## Product Types

When creating targets, use these Apple product type identifiers:

- `com.apple.product-type.application` - iOS/macOS App
- `com.apple.product-type.framework` - Dynamic Framework
- `com.apple.product-type.library.static` - Static Library
- `com.apple.product-type.bundle` - Bundle
- `com.apple.product-type.bundle.unit-test` - Unit Test Bundle
- `com.apple.product-type.bundle.ui-testing` - UI Test Bundle
- `com.apple.product-type.app-extension` - App Extension
- `com.apple.product-type.watchkit2-extension` - WatchKit Extension

## Advanced Usage

### Tips for Efficient Usage

**Batch Operations**
```bash
# Add multiple files with different groups
xcodeproj-cli add-files \
  Model.swift:Models \
  View.swift:Views \
  ViewModel.swift:ViewModels \
  --targets MyApp,MyAppTests

# Create a complete group structure at once
xcodeproj-cli create-groups \
  Features/Authentication \
  Features/Profile \
  Features/Settings \
  Services/API \
  Services/Storage
```

**Using Dry-Run Mode**
```bash
# Always test complex operations first
xcodeproj-cli --dry-run add-folder LargeFolder / MyApp --recursive
# Review output, then run without --dry-run if correct
```

**Using Verbose Mode for Performance Insights**
```bash
# Monitor operation performance and cache efficiency
xcodeproj-cli --verbose add-folder Sources/Features --group Features --targets MyApp --recursive

# Example verbose output:
# Cache hit rate: 85% (17/20 lookups)
# Operation timing: 127ms total
# Files processed: 15
# Groups created: 3
```

### Real-World Examples

**Example 1: Adding a new feature module**
```bash
# Add source files from a feature folder (groups are created automatically)
xcodeproj-cli add-folder Sources/Checkout --group Features/Checkout --targets ShoppingCart --recursive

# Add the payment SDK
xcodeproj-cli add-swift-package https://github.com/stripe/stripe-ios --requirement "from: 23.0.0" --target ShoppingCart
```

**Example 2: Setting up a Pro version of your app**
```bash
# Duplicate the target
xcodeproj-cli duplicate-target MyApp MyAppPro --bundle-id com.example.pro

# Customize the Pro version
xcodeproj-cli set-build-setting PRODUCT_NAME "MyApp Pro" --targets MyAppPro
xcodeproj-cli set-build-setting ENABLE_PRO_FEATURES YES --targets MyAppPro
```

**Example 3: Organizing an existing messy project**
```bash
# Create a clean structure with groups (no files are moved on disk)
xcodeproj-cli create-groups \
  Architecture/Models \
  Architecture/Views \
  Architecture/ViewModels \
  Architecture/Services \
  Architecture/Utilities

# Now you can add existing files to these groups
xcodeproj-cli add-file Sources/User.swift --group Architecture/Models --targets MyApp
xcodeproj-cli add-file Sources/LoginView.swift --group Architecture/Views --targets MyApp
```

## Error Handling

The tool provides clear error messages for common issues:

- File already exists in project
- Group or target not found
- Invalid product type
- Missing required parameters
- Validation failures

## Performance

- **Fast execution** - No Xcode or Docker overhead
- **Batch processing** - Multiple operations in single run
- **Smart caching** - Swift Package Manager caches dependencies
- **Intelligent caching system** - Multi-level caching with O(1) lookups for groups, targets, and file references
- **Performance profiling** - Use `--verbose` flag to see operation timing and cache statistics
- **Minimal dependencies** - Only requires XcodeProj library
- **Memory efficient** - Lazy initialization and automatic cleanup
- **Optimized for large projects** - Tested with 1000+ files

## Comparison with Alternatives

| Feature | xcodeproj-cli | xcodeproj-mcp-server | Xcode |
|---------|---------------|---------------------|-------|
| No Dependencies | ✅ | ❌ (Docker) | ✅ |
| Installation Speed | ✅ Fast | ❌ Slow | N/A |
| Execution Speed | ✅ Fastest | ❌ Slower | ❌ Slow |
| Command Line | ✅ | ✅ | ❌ |
| Scriptable | ✅ | ✅ | ⚠️ |
| All Project Features | ✅ | ⚠️ | ✅ |
| Universal Binary | ✅ | ❌ Docker | ✅ |

## Troubleshooting

### Common Issues

**Permission denied**
```bash
chmod +x xcodeproj-cli
```

**XcodeProj dependency error**
```bash
# Clear SPM cache and retry
rm -rf .build
swift build -c release
```

**Project file backup**
```bash
# Always backup before major changes
cp -r PhotoEditor.xcodeproj PhotoEditor.xcodeproj.backup
```

## Testing

The project includes a comprehensive test suite with 136+ tests covering all functionality using Swift Package Manager.

### Running Tests

```bash
# Run all tests using Swift Package Manager
swift test

# Run specific test suites
swift test --filter ValidationTests      # Read-only validation tests
swift test --filter FileOperationsTests  # File manipulation tests
swift test --filter BuildAndTargetTests  # Target and build tests
swift test --filter PackageTests         # Swift package tests
swift test --filter SecurityTests        # Security tests

# Run with code coverage
swift test --enable-code-coverage

# Run tests in parallel for faster execution
swift test --parallel
```

### Test Categories

- **BasicTests** - Core CLI functionality
- **ValidationTests** - Read-only operations that don't modify projects
- **FileOperationsTests** - File and folder manipulation  
- **BuildAndTargetTests** - Target management and build settings
- **ComprehensiveTests** - Full feature coverage tests
- **IntegrationTests** - Complex multi-command workflows
- **PackageTests** - Swift Package Manager integration
- **SecurityTests** - Path traversal and injection protection
- **AdditionalTests** - Edge cases and error handling

## Contributing

This tool is open for improvements! Feel free to:

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass (`swift test`)
5. Submit a pull request

Areas for contribution:
- Add new commands for specific workflows
- Enhance error messages
- Add more file type support
- Improve performance
- Expand test coverage

## License

MIT License - see [LICENSE](./LICENSE) file for details.

## Project Structure

```
xcodeproj-cli/
├── Sources/
│   └── xcodeproj-cli/
│       ├── ArgumentParser/               # ArgumentParser-based CLI layer
│       │   ├── XcodeProjCLI.swift        # Main command structure (@main)
│       │   ├── GlobalOptions.swift       # Shared options (--project, --verbose, --dry-run)
│       │   ├── ProjectServiceFactory.swift # Service initialization
│       │   └── Commands/                 # 52 command implementations
│       │       ├── FileCommands/         # File operations (6 commands)
│       │       ├── TargetCommands/       # Target management (7 commands)
│       │       ├── GroupCommands/        # Group operations (3 commands)
│       │       ├── BuildCommands/        # Build configuration (5 commands)
│       │       ├── PackageCommands/      # Swift packages (4 commands)
│       │       ├── SchemeCommands/       # Scheme management (7 commands)
│       │       ├── WorkspaceCommands/    # Workspace operations (6 commands)
│       │       ├── InspectionCommands/   # Validation (5 commands)
│       │       ├── ProductCommands/      # Product references (5 commands)
│       │       ├── PathCommands/         # Path updates (2 commands)
│       │       └── FrameworkCommands/    # Framework management (2 commands)
│       ├── Services/                     # Extracted focused services
│       │   ├── FileService.swift         # File operations (~400 lines)
│       │   ├── TargetService.swift       # Target management (~350 lines)
│       │   ├── GroupService.swift        # Group hierarchy (~300 lines)
│       │   ├── PackageService.swift      # SPM integration (~250 lines)
│       │   ├── BuildSettingsService.swift # Build config (~200 lines)
│       │   ├── TransactionService.swift  # Safe operations
│       │   └── ValidationService.swift   # Project validation
│       ├── Core/                         # Core utilities and managers
│       │   ├── XcodeProjUtility.swift    # Coordination layer (~486 lines)
│       │   ├── XcodeProjService.swift    # Project loading
│       │   ├── CacheManager.swift        # Performance caching
│       │   ├── BuildPhaseManager.swift   # Build phase operations
│       │   └── ProductReferenceManager.swift # Product references
│       ├── Models/                       # Data structures and error types
│       └── Utils/                        # Utility functions and helpers
├── Package.swift                         # Swift Package Manager configuration
├── ARCHITECTURE.md                       # Detailed architecture documentation
├── build-universal.sh                    # Universal binary build script
├── .github/
│   └── workflows/
│       └── release.yml                   # Automated release workflow
├── Tests/
│   └── xcodeproj-cliTests/              # Swift Package Manager tests (372+ tests)
│       ├── BasicTests.swift              # Core functionality tests
│       ├── FileOperationsTests.swift     # File manipulation tests
│       ├── BuildAndTargetTests.swift     # Target and build configuration tests
│       ├── ComprehensiveTests.swift      # Complete feature coverage tests
│       ├── ValidationTests.swift         # Project validation tests
│       ├── IntegrationTests.swift        # Complex workflow tests
│       ├── PackageTests.swift            # Swift Package Manager tests
│       ├── SecurityTests.swift           # Security-focused test coverage
│       ├── AdditionalTests.swift         # Extended test scenarios
│       ├── CLIRegressionTests/           # CLI behavior regression tests
│       ├── TestHelpers.swift             # Shared test utilities
│       └── TestResources/                # Test project and sample files
│           └── TestProject.xcodeproj/    # Test project for validation
├── README.md                             # This file
├── CHANGELOG.md                          # Version history and changes
├── LICENSE                               # MIT License
└── install.sh                            # Installation script
```

**For Developers**: See [ARCHITECTURE.md](./ARCHITECTURE.md) for detailed information about the modular architecture, design patterns, performance optimizations, and extension points.

## Credits & Attribution

### Dependencies
- **[XcodeProj](https://github.com/tuist/XcodeProj)** (MIT License)
  - Created and maintained by the [Tuist](https://tuist.io) team
  - Provides the core Xcode project file manipulation capabilities
  - Version: 9.4.3+

- **[PathKit](https://github.com/kylef/PathKit)** (BSD License)
  - Created by Kyle Fuller
  - Provides path manipulation utilities
  - Version: 1.0.0+

- **[swift-argument-parser](https://github.com/apple/swift-argument-parser)** (Apache 2.0 License)
  - Created and maintained by Apple
  - Provides type-safe CLI argument parsing with auto-generated help
  - Version: 1.5.0+

### Inspiration
- **[xcodeproj-mcp-server](https://github.com/giginet/xcodeproj-mcp-server)** (MIT License)
  - Created by giginet
  - Inspired the comprehensive feature set and command structure
  - This tool reimplements similar functionality as a standalone binary

### Contributors
This tool was developed for Xcode project automation and is released under the MIT License for community use.

## Support

For issues, questions, or contributions, please visit:
https://github.com/tolo/xcodeproj-cli

## Changelog

See [CHANGELOG.md](./CHANGELOG.md) for a detailed history of changes.
