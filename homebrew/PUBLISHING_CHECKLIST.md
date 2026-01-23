# Homebrew Publishing Checklist for xcodeproj-cli

## Prerequisites ✅
- [x] Created `tolo/homebrew-xcodeproj` repository
- [x] GitHub Actions release workflow configured (`.github/workflows/release.yml`)
- [x] Universal binary build script ready (`build-universal.sh`)

## Release Process

### Step 1: Final Preparations
- [ ] Ensure all PRs are merged to main
- [ ] Update CHANGELOG.md - change `[UNRELEASED]` to `[X.Y.Z] - YYYY-MM-DD`
- [ ] Verify version in `Sources/xcodeproj-cli/ArgumentParser/XcodeProjCLI.swift:15` is "X.Y.Z"
- [ ] Run final tests: `swift test`
- [ ] Build and test universal binary: `./build-universal.sh`

### Step 2: Create Git Tag and Trigger Release
```bash
# Commit any final changes
git add -A
git commit -m "Release vX.Y.Z"
git push origin main

# Create and push version tag (this triggers GitHub Actions)
git tag vX.Y.Z
git push origin vX.Y.Z
```

### Step 3: Monitor GitHub Actions
1. Go to https://github.com/tolo/xcodeproj-cli/actions
2. Watch the "Build and Release" workflow
3. Wait for it to complete successfully
4. Note the SHA256 hash from the workflow output

### Step 4: Verify GitHub Release
1. Go to https://github.com/tolo/xcodeproj-cli/releases
2. Verify release vX.Y.Z was created
3. Download and test the binary:
```bash
curl -L https://github.com/tolo/xcodeproj-cli/releases/download/vX.Y.Z/xcodeproj-cli-vX.Y.Z-macos.tar.gz -o test.tar.gz
tar -xzf test.tar.gz
./xcodeproj-cli --version  # Should show X.Y.Z
rm test.tar.gz xcodeproj-cli
```

### Step 5: Setup Homebrew Tap Repository
1. Clone your tap repository:
```bash
git clone https://github.com/tolo/homebrew-xcodeproj.git
cd homebrew-xcodeproj
```

2. Copy the formula file:
```bash
cp /path/to/xcodeproj-tool/homebrew/xcodeproj-cli.rb Formula/xcodeproj-cli.rb
```

3. Update the SHA256 in the formula:
   - Get SHA256 from GitHub Actions output or calculate it:
   ```bash
   shasum -a 256 xcodeproj-cli-vX.Y.Z-macos.tar.gz
   ```
   - Replace `PLACEHOLDER_SHA256_TO_BE_UPDATED_AFTER_RELEASE` in the formula

4. Copy README if needed:
```bash
cp /path/to/xcodeproj-tool/homebrew/README.md README.md
```

5. Commit and push:
```bash
git add .
git commit -m "Add xcodeproj-cli formula vX.Y.Z"
git push origin main
```

### Step 6: Test Homebrew Installation
```bash
# Test the tap
brew tap tolo/xcodeproj
brew install xcodeproj-cli

# Verify it works
xcodeproj-cli --version
xcodeproj-cli --help

# Test with a real project
xcodeproj-cli --project /path/to/test.xcodeproj list-targets
```

### Step 7: Update Documentation
- [ ] Update README.md installation instructions (if needed)
- [ ] Create announcement/release notes
- [ ] Update any external documentation

### Step 8: Announce Release
- [ ] Create GitHub Discussion or Issue announcement
- [ ] Share on social media (if applicable)
- [ ] Notify any major users

## Troubleshooting

### If GitHub Actions fails:
1. Check the error in the Actions tab
2. Fix the issue in the workflow file
3. Delete the tag: `git tag -d v2.0.0 && git push origin :refs/tags/v2.0.0`
4. Make fixes and try again

### If Homebrew installation fails:
1. Check formula syntax: `brew audit --strict Formula/xcodeproj-cli.rb`
2. Test locally: `brew install --build-from-source Formula/xcodeproj-cli.rb`
3. Fix issues and push updates

### To update the formula after release:
1. Update version number in formula
2. Update URL to point to new release
3. Update SHA256 hash
4. Commit and push changes

## Future Releases

For future releases (e.g., v2.0.1):
1. Update version in source code
2. Update CHANGELOG.md
3. Follow steps 2-8 above
4. The formula URL pattern is:
   ```
   https://github.com/tolo/xcodeproj-cli/releases/download/vX.Y.Z/xcodeproj-cli-vX.Y.Z-macos.tar.gz
   ```

## Notes
- The GitHub Actions workflow automatically creates the release and uploads the binary
- The SHA256 hash is shown in the GitHub Actions output
- Always test the Homebrew installation after publishing
- Keep the tap repository simple - just Formula/ directory and README