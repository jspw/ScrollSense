class Scrollsense < Formula
  desc "Automatically switches macOS natural scroll direction based on mouse or trackpad"
  homepage "https://github.com/jspw/ScrollSense"
  url "https://github.com/jspw/ScrollSense/archive/refs/tags/v1.0.6.tar.gz"
  sha256 "777cb3bbb994114e5dbf3ff09af43fa764d4b43772b0fc9fdb6fff741f608b7c"
  license "MIT"

  depends_on xcode: ["14.0", :build]
  depends_on :macos

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"
    bin.install ".build/release/scrollSense"
  end

  def caveats
    <<~EOS
      scrollSense requires Accessibility permission to monitor input events.

      Grant permission in:
        System Settings → Privacy & Security → Accessibility

      Add your terminal app or the scrollSense binary.

      Quick start:
        scrollSense set --mouse false --trackpad true
        scrollSense start

      To auto-start at login:
        scrollSense install
    EOS
  end

  service do
    run [opt_bin/"scrollSense", "run"]
    keep_alive true
    log_path var/"log/scrollsense.log"
    error_log_path var/"log/scrollsense.error.log"
  end

  test do
    assert_match "1.0.6", shell_output("#{bin}/scrollSense --version")
  end
end
