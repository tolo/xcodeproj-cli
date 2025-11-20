# Golden Files

This directory contains golden files for CLI regression testing. Golden files capture the expected output of CLI commands to ensure no regressions occur during refactoring or migration.

## Directory Structure

```
GoldenFiles/
├── commands/          # Output from successful command executions
├── help/             # Help text for commands
└── errors/           # Error messages and scenarios
```

## Usage

### Running Tests

Tests automatically compare CLI output against golden files:

```bash
swift test --filter CLIRegressionTests
```

### Updating Golden Files

When CLI output intentionally changes, update golden files:

```bash
GOLDEN_UPDATE=1 swift test --filter CLIRegressionTests
```

This regenerates all golden files based on current CLI output.

### Creating New Golden Files

1. Add a test method in `CommandRegressionTests.swift`
2. Run with `GOLDEN_UPDATE=1` to generate the golden file
3. Verify the generated output is correct
4. Commit the golden file to git

## Golden File Format

- Plain text files with `.golden` extension
- Normalized to remove:
  - Timestamps
  - Temporary paths
  - UUIDs
  - Other variable content

## Best Practices

- **Version Control**: Always commit golden files to git
- **Review Changes**: Carefully review any changes to golden files
- **Test Coverage**: Create golden files for both success and error cases
- **Documentation**: Add comments in test code explaining what each golden file tests

## Current Coverage

### Commands (Read-Only)
- `validate-clean.golden` - Project validation output
- `list-targets.golden` - Target listing
- `list-groups.golden` - Group listing
- `list-files.golden` - File listing
- `list-tree.golden` - Tree view
- `list-build-configs.golden` - Build configurations
- `list-swift-packages.golden` - Swift packages
- `list-schemes.golden` - Scheme listing
- `list-invalid-references.golden` - Invalid references

### Help Text
- `main-help.golden` - Main help output
- `version-info.golden` - Version information

### Errors
- `project-not-found.golden` - Missing project error

## TODO

- [ ] Add golden files for all 52 commands
- [ ] Add help text for each command
- [ ] Add error scenarios for common failure cases
- [ ] Add golden files for file modification commands
- [ ] Add golden files for workspace commands
