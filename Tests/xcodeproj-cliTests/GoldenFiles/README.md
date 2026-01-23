# Golden Files for CLI Regression Tests

This directory contains golden files (reference outputs) for CLI regression testing to ensure consistent behavior across releases.

## Purpose

Golden files ensure that:
1. **Command output format** remains consistent across releases
2. **Help text** is accurate and well-formatted
3. **Error messages** are clear and actionable
4. **Breaking changes** to CLI interface are detected early
5. **Regression prevention** - Unintentional output changes are caught

## Directory Structure

```
GoldenFiles/
├── commands/     - Command execution outputs (62 files)
│   ├── list-targets.golden
│   ├── validate-clean.golden
│   ├── get-build-settings.golden
│   └── ...
├── help/         - Help text for all commands (69 files)
│   ├── main-help.golden
│   ├── add-file-help.golden
│   ├── set-build-setting-help.golden
│   └── ...
└── errors/       - Error messages and edge cases (8 files)
    ├── project-not-found.golden
    ├── invalid-command-format.golden
    └── ...
```

**Total:** 139 golden files tracking CLI behavior

## File Format

Each golden file:
- Has `.golden` extension
- Contains **normalized** CLI output:
  - Absolute paths replaced with relative paths
  - Timestamps removed for consistency
  - Platform-specific details normalized
- Uses **UTF-8 encoding**
- Uses **UNIX line endings (LF)**
- Is **human-readable** for easy review

## When to Update Golden Files

Update golden files when you **intentionally** change:

✅ **Acceptable reasons to update:**
1. Improved error messages (clearer, more helpful)
2. Enhanced help text (better examples, documentation)
3. New command-line options added
4. Output format improvements (better tables, colors)
5. New commands added to CLI

❌ **Should NOT update for:**
1. Failing tests from unintentional changes
2. Breaking changes without discussion
3. Temporary debugging output
4. Platform-specific quirks

## Updating Golden Files

### Method 1: Update All Golden Files

```bash
# Regenerate ALL golden files
GOLDEN_UPDATE=1 swift test

# This will update every .golden file based on current CLI output
# Use with caution - review all changes!
```

### Method 2: Update Specific Test Suite

```bash
# Update only help text golden files
GOLDEN_UPDATE=1 swift test --filter HelpTextTests

# Update only command output golden files
GOLDEN_UPDATE=1 swift test --filter CommandRegressionTests

# Update only argument parsing golden files
GOLDEN_UPDATE=1 swift test --filter ArgumentParsingTests

# Update only output format golden files
GOLDEN_UPDATE=1 swift test --filter OutputFormatTests
```

### Method 3: Update Single Test

```bash
# Update golden file for one specific test
GOLDEN_UPDATE=1 swift test --filter HelpTextTests/testAddFileHelp
```

## Complete Update Workflow

Follow this workflow to safely update golden files:

### Step 1: Identify Changes
```bash
# Run tests to see which golden files don't match
swift test --filter ArgumentParsingTests

# Example output:
# ❌ Golden file comparison failed for 'help-flag-long'
# ❌ Expected: xcodeproj-cli v2.3.0
# ❌ Actual:   xcodeproj-cli v2.4.0
```

### Step 2: Review Changes
```bash
# Before updating, understand WHAT changed and WHY
# Review the code changes that affected output
git diff Sources/xcodeproj-cli/
```

### Step 3: Update Golden Files
```bash
# Update affected golden files
GOLDEN_UPDATE=1 swift test --filter ArgumentParsingTests

# You'll see:
# ✓ Updated golden file: help-flag-long.golden
# ✓ Updated golden file: help-flag-short.golden
```

### Step 4: Verify Tests Pass
```bash
# Run tests again WITHOUT GOLDEN_UPDATE to confirm
swift test --filter ArgumentParsingTests

# All tests should now pass
```

### Step 5: Review Diffs
```bash
# Review EVERY changed golden file
git diff Tests/xcodeproj-cliTests/GoldenFiles/

# Check:
# - Are changes intentional?
# - Do they improve the CLI?
# - Are error messages clearer?
# - Is help text more helpful?
```

### Step 6: Commit Changes
```bash
# Stage golden file changes
git add Tests/xcodeproj-cliTests/GoldenFiles/

# Write descriptive commit message explaining WHY
git commit -m "Update golden files: Improved error messages for missing targets

- Enhanced error messages to include suggestions
- Updated help text with more examples
- Fixed inconsistent formatting in list-targets output"
```

## Best Practices

### DO ✅
1. **Review every golden file diff** before committing
2. **Test without GOLDEN_UPDATE=1** after updating to verify tests pass
3. **Document reasons** in PR/commit message for why golden files changed
4. **Update incrementally** - one test suite at a time when possible
5. **Keep golden files readable** - they're documentation of CLI behavior

### DON'T ❌
1. **Don't blindly update** all golden files without reviewing
2. **Don't commit failing tests** and update golden files to "fix" them
3. **Don't update golden files** to hide bugs or regressions
4. **Don't include debug output** in golden files
5. **Don't mix** golden file updates with unrelated code changes

## Troubleshooting

### Issue: "Golden file comparison failed"

**Symptom:**
```
❌ Golden file comparison failed for 'validate-clean'

Expected:
✓ Project is valid

Actual:
✅ Project is valid
```

**Solution:** Output format changed (checkmark style). Decide if this is intentional:
- ✅ **Intentional:** Update golden file with `GOLDEN_UPDATE=1`
- ❌ **Unintentional:** Fix code to match expected output

### Issue: "Golden file not found"

**Symptom:**
```
❌ Golden file not found: new-command.golden
```

**Solution:** You added a new test but no golden file exists yet:
```bash
# Generate golden file for new test
GOLDEN_UPDATE=1 swift test --filter YourNewTest
```

### Issue: Golden files show path differences

**Symptom:**
```
Expected: /Users/user1/project/file.swift
Actual:   /Users/user2/project/file.swift
```

**Solution:** Golden files should use **normalized paths**. Check `CLITestHarness.normalizeOutput()` is working correctly.

## Golden File Normalization

The `CLITestHarness` automatically normalizes output before comparison:

```swift
static func normalizeOutput(_ output: String) -> String {
    // Removes absolute paths, timestamps, and platform-specific details
    // See: Tests/xcodeproj-cliTests/CLIRegressionTests/CLITestHarness.swift
}
```

## CI/CD Integration

Golden file tests run automatically in CI:

```yaml
# .github/workflows/test.yml
- name: Run Tests
  run: swift test

# Golden files are checked in and validated
# No GOLDEN_UPDATE=1 in CI - tests must pass with existing golden files
```

## Related Documentation

- **CLITestHarness.swift** - Test infrastructure
- **GoldenFileManager.swift** - Golden file loading/saving
- **ArgumentParsingTests.swift** - Argument parsing test examples
- **HelpTextTests.swift** - Help text test examples

## Summary

Golden files are **reference outputs** that ensure CLI consistency. When making changes that affect CLI output:

1. Run tests to see what changed
2. Review changes - are they intentional improvements?
3. Update golden files with `GOLDEN_UPDATE=1`
4. Verify tests pass without `GOLDEN_UPDATE=1`
5. Review all diffs and document why
6. Commit with clear explanation

**Remember:** Golden files are documentation of CLI behavior. Treat them like code - review carefully before updating.
