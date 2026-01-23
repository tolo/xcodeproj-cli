class XcodeprojCli < Formula
  desc "Command-line tool for manipulating Xcode project files"
  homepage "https://github.com/tolo/xcodeproj-cli"
  version "2.5.0"

  url "https://github.com/tolo/xcodeproj-cli/releases/download/v2.5.0/xcodeproj-cli-v2.5.0-macos.tar.gz"
  sha256 "4122968536a456c2e71715351730305d057d4f0665752eadf82691ebc1ac676d"

  license "MIT"

  depends_on macos: :catalina

  def install
    bin.install "xcodeproj-cli"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/xcodeproj-cli --version")

    output = shell_output("#{bin}/xcodeproj-cli --help")
    assert_match "Xcode project manipulation", output
    assert_match "USAGE:", output

    output = shell_output("#{bin}/xcodeproj-cli list-targets 2>&1", 1)
    assert_match "Error", output
  end

  def caveats
    <<~EOS
      xcodeproj-cli has been installed!

      Quick start:
        xcodeproj-cli --help
        xcodeproj-cli --project MyApp.xcodeproj list-targets

      For more information:
        https://github.com/tolo/xcodeproj-cli
    EOS
  end
end
