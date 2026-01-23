# CLI Regression Tests - Phase 0 Baseline

This directory contains CLI regression test infrastructure created as Phase 0 of the ArgumentParser migration.

## Purpose

Capture exact CLI behavior BEFORE ArgumentParser migration to ensure zero regression during the transition.

## Current Status

### ✅ Completed Infrastructure
- `CLITestHarness.swift` - Executes CLI commands via Process API
- `GoldenFileManager.swift` - Manages golden file comparisons with UPDATE mode
- `CommandRegressionTests.swift` - Test suite with 11 tests implemented
- Golden files directory structure with 9 baseline files
- Package.swift updated for test resources

### ⚠️ Known Issues
1. **Path Resolution**: Test resource and binary paths need environment-specific adjustment
2. **Test Execution**: Infrastructure compiles but tests fail due to path resolution
3. **Coverage**: Only 9/100+ golden files created

### 📋 TODO
- [ ] Fix path resolution for test execution
- [ ] Generate golden files for all 52 commands
- [ ] Add ArgumentParsingTests (flag combinations, ordering)
- [ ] Add OutputFormatTests (table, tree, JSON formats)
- [ ] Add HelpTextTests for all commands
- [ ] Add error scenario tests
- [ ] Add performance baseline tests

## Usage

### Running Tests
```bash
swift test --filter CLIRegressionTests
```

### Updating Golden Files
```bash
GOLDEN_UPDATE=1 swift test --filter CLIRegressionTests
```

### Generating Golden Files
```bash
# Example for a command
.build/debug/xcodeproj-cli --project Tests/xcodeproj-cliTests/TestResources/TestProject.xcodeproj validate > Tests/xcodeproj-cliTests/GoldenFiles/commands/validate-clean.golden
```

## Architecture

- **CLITestHarness**: Uses Process API to execute actual CLI binary
- **GoldenFileManager**: Normalizes output (timestamps, paths, UUIDs) before comparison
- **Test Structure**: Each command has dedicated test method comparing against golden file

## Next Steps

1. **Fix Path Issues**: Update `cliExecutablePath()` and `testResourcesPath()` for SPM test environment
2. **Complete Coverage**: Generate golden files for all 52 commands
3. **Verify Baseline**: Ensure all tests pass on main branch before migration
4. **Move to Feature Branch**: Transfer baseline to feature/swift-argument-parser
5. **Use as Safety Net**: Run tests after each ArgumentParser change

## Notes

- This is the BASELINE captured from main branch (pre-ArgumentParser)
- Once working, this becomes the regression safety net for migration
- DO NOT modify golden files unless CLI behavior intentionally changes
