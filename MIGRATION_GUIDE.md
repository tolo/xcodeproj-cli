# Migration Guide: v2.3.x → v2.4.0

This guide helps users upgrade from version 2.3.x to 2.4.0, which introduces the migration to swift-argument-parser and enhanced security features.

## Overview

Version 2.4.0 represents a **major architectural refactoring** that:
- Migrates CLI from custom command registry to Apple's swift-argument-parser
- Extracts business logic into dedicated service classes
- Enhances security validation for paths and build settings
- Maintains backward compatibility for most commands

## Breaking Changes

### 1. Command-Line Interface Changes

#### Version Flag Only
**Before (v2.3.x):**
```bash
xcodeproj-cli -v       # Short form for version
```

**After (v2.4.0):**
```bash
xcodeproj-cli --version   # Long form required
# Note: -v is not available because -V is used for --verbose
```

**Reason:** swift-argument-parser reserves `-V` for verbose output, making `-v` unavailable for version. Most modern CLI tools use `--version` anyway (e.g., `git --version`, `npm --version`).

**Help flags UNCHANGED:**
```bash
xcodeproj-cli -h          # ✅ Still works
xcodeproj-cli --help      # ✅ Still works
xcodeproj-cli cmd -h      # ✅ Still works for subcommands
```

### 2. Error Message Format

Error messages now follow ArgumentParser conventions:

**Before (v2.3.x):**
```
Error: Target 'NonExistent' not found
```

**After (v2.4.0):**
```
Error: Target not found: NonExistent
Usage: xcodeproj-cli <command> [options]
  See 'xcodeproj-cli --help' for more information.
```

**Impact:** Scripts parsing error output may need updates.

### 3. Build Setting Validation (Enhanced Security)

**v2.4.0 introduces stricter validation** for build settings in dangerous categories:

**Blocked patterns in** `OTHER_LDFLAGS`, `OTHER_SWIFT_FLAGS`, `HEADER_SEARCH_PATHS`, etc.:
- Command substitution: `$(...)`, `` `...` ``
- Variable expansion with `${...}`
- Command chaining: `;`, `&&`, `||`
- Pipes and redirects: `|`, `>`, `<`
- Path traversal: `../`

**Example - This will now FAIL:**
```bash
# Before: Accepted (security risk!)
xcodeproj-cli set-build-setting OTHER_LDFLAGS "$(BUILT_PRODUCTS_DIR)/lib" \
  --targets MyApp

# After: Rejected for security
# Error: Build setting 'OTHER_LDFLAGS' contains potentially dangerous value
```

**Workaround:** For legitimate Xcode variables in search paths, use safer build setting keys:
```bash
# Use non-dangerous settings for Xcode variables
xcodeproj-cli set-build-setting PRODUCT_NAME "$(TARGET_NAME)" --targets MyApp
xcodeproj-cli set-build-setting INFOPLIST_FILE "$(SRCROOT)/Info.plist" --targets MyApp
```

### 4. Path Validation (Enhanced Security)

**v2.4.0 blocks critical system paths:**

**Now blocked:**
- `/etc/*`
- `/private/etc/*`
- `/System/Library/LaunchDaemons/*`
- `/usr/bin/sudo`

**Example - This will now FAIL:**
```bash
# Before: Accepted (security risk!)
xcodeproj-cli add-file /etc/passwd --group Sources --targets MyApp

# After: Rejected for security
# Error: Invalid file path: Critical system path not allowed
```

### 5. Shell Script Validation

**v2.4.0 balances security with usability:**

**Still allowed** (legitimate build scripts):
- Multi-line scripts with `\n`
- Command sequences with `;`
- Tool chaining with `|` (e.g., `swiftlint | xcpretty`)
- File I/O with `>`, `>>`, `<`
- Conditional execution with `&&`, `||`
- Xcode build variables with `${VAR}`

**Still blocked** (code injection risks):
- Command substitution: `$(...)`, `` `...` ``
- Code evaluation: `eval`, `exec`
- Piping to shells: `| sh`, `| bash`, `| zsh`
- Path traversal in commands: `../`

## Migration Steps

### Step 1: Update Installation

```bash
# Update via Homebrew
brew update
brew upgrade xcodeproj-cli

# Verify version
xcodeproj-cli --version
# Should output: 2.4.0
```

### Step 2: Update Scripts

#### Update Version Flag (if needed)
```bash
# Only need to update -v to --version
# -h continues to work, no changes needed
sed -i '' 's/xcodeproj-cli -v/xcodeproj-cli --version/g' *.sh
```

#### Update Error Handling
If your scripts parse error messages, update patterns:

**Before:**
```bash
if xcodeproj-cli add-file ... 2>&1 | grep -q "Error: "; then
    echo "Command failed"
fi
```

**After:**
```bash
if ! xcodeproj-cli add-file ...; then
    echo "Command failed with exit code $?"
fi
```

### Step 3: Review Build Settings

Audit existing build settings that may now be rejected:

```bash
# List all build settings
xcodeproj-cli list-build-settings --target YourTarget --all

# Review dangerous categories
xcodeproj-cli get-build-settings YourTarget | grep -E "(OTHER_|SEARCH_PATHS)"
```

If you have build settings using `$(...)` or `${...}` in dangerous categories, you'll need to:
1. Move them to non-dangerous setting keys if possible
2. Use absolute paths instead of variable expansion
3. Contact maintainers if legitimate use case blocked

### Step 4: Review Custom Shell Scripts

Check build phase shell scripts:

```bash
# Extract and review shell scripts from project
grep -r "shellScript" YourProject.xcodeproj/project.pbxproj
```

Ensure scripts don't use blocked patterns. If you need command substitution, consider:
1. Generating values at build configuration time
2. Using Xcode build settings instead
3. Pre-generating files rather than dynamic execution

### Step 5: Test Thoroughly

```bash
# Test all common operations
xcodeproj-cli validate --project YourProject.xcodeproj
xcodeproj-cli list-targets
xcodeproj-cli add-file TestFile.swift --group Sources --targets YourTarget

# Test with --dry-run to preview changes
xcodeproj-cli set-build-setting SWIFT_VERSION 5.9 --targets YourTarget --dry-run
```

## Compatibility Matrix

| Feature | v2.3.x | v2.4.0 | Notes |
|---------|--------|--------|-------|
| All file operations | ✅ | ✅ | Unchanged |
| All target operations | ✅ | ✅ | Unchanged |
| Build settings (safe) | ✅ | ✅ | Unchanged |
| Build settings with `$()` | ✅ | ❌ | Security enhancement |
| Path traversal (`../`) | ❌ | ❌ | Unchanged (blocked) |
| Critical system paths | ⚠️ | ❌ | Enhanced blocking |
| `-h` help flag | ✅ | ✅ | **Still works!** |
| `--help` flag | ✅ | ✅ | Unchanged |
| `-v` version flag | ✅ | ❌ | Use `--version` (only change) |
| `--version` flag | ✅ | ✅ | Unchanged |
| Shell scripts (legitimate) | ✅ | ✅ | More permissive |
| Shell scripts (malicious) | ⚠️ | ❌ | Better detection |

## New Features in v2.4.0

### 1. Enhanced Service Architecture

Internal refactoring provides better separation of concerns:
- `FileService` - File operations
- `TargetService` - Target management
- `GroupService` - Group operations
- `BuildSettingsService` - Build configuration
- `PackageService` - Swift Package Manager

*No user-facing changes, but improves maintainability and future extensibility.*

### 2. Improved Error Messages

ArgumentParser provides clearer, more consistent error messages with usage hints.

### 3. Comprehensive Test Coverage

- 457 total tests (up from 380)
- 100+ golden file regression tests
- 24 new security validation tests
- CLI regression test suite

## Troubleshooting

### Issue: "Error: Unknown option '-v'"

**Symptom:**
```
Error: Unknown option '-v'
Usage: xcodeproj-cli [options] <subcommand>
```

**Solution:** Use long-form flag for version:
```bash
xcodeproj-cli --version   # instead of -v
```

**Note:** The `-h` help flag still works! Only `-v` for version is affected.

### Issue: "Build setting contains potentially dangerous value"

**Symptom:**
```
Error: Operation failed: Build setting 'OTHER_LDFLAGS' contains potentially dangerous value
```

**Solution:** Remove command substitution or move to safer setting:
```bash
# Bad: Uses $() in dangerous setting
xcodeproj-cli set-build-setting OTHER_LDFLAGS "$(BUILT_PRODUCTS_DIR)/lib" ...

# Good: Use literal paths or move to PRODUCT_NAME, INFOPLIST_FILE, etc.
xcodeproj-cli set-build-setting OTHER_LDFLAGS "-L/path/to/libs" ...
```

### Issue: "Invalid file path: Critical system path not allowed"

**Symptom:**
```
Error: Invalid file path: Critical system path not allowed
```

**Solution:** You're trying to add references to critical system files. This is blocked for security. For frameworks:
```bash
# Instead of adding /System/Library/Frameworks/Foundation.framework
# Use add-framework command which handles system frameworks safely
xcodeproj-cli add-framework Foundation --targets MyApp
```

## Rollback Instructions

If you encounter issues and need to rollback:

```bash
# Rollback via Homebrew
brew uninstall xcodeproj-cli
brew install xcodeproj-cli@2.3

# Or download specific version
curl -L https://github.com/tolo/xcodeproj-cli/releases/download/v2.3.1/xcodeproj-cli -o /usr/local/bin/xcodeproj-cli
chmod +x /usr/local/bin/xcodeproj-cli
```

**Note:** After rolling back, restore project backups if changes were made:
```bash
cp -r YourProject.xcodeproj.backup YourProject.xcodeproj
```

## Getting Help

If you encounter migration issues:

1. **Check existing issues:** https://github.com/tolo/xcodeproj-cli/issues
2. **Create new issue:** Include:
   - xcodeproj-cli version (`xcodeproj-cli --version`)
   - Command that failed
   - Full error message
   - Xcode version
3. **Discussions:** https://github.com/tolo/xcodeproj-cli/discussions

## Summary

Version 2.4.0 brings significant internal improvements while maintaining backward compatibility for almost all use cases. The main changes requiring attention are:

1. ✅ Update `-v` to `--version` in automation scripts (only if you use `-v`)
2. ✅ Review build settings with variable expansion in dangerous categories
3. ✅ Test shell scripts for blocked patterns
4. ✅ Update error message parsing if applicable

**Good news:** The `-h` help flag still works! Most users will experience a seamless upgrade with enhanced security and better error messages.
