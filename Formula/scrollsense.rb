class Scrollsense < Formula
  desc "Automatically switches macOS natural scroll direction based on mouse or trackpad"
  homepage "https://github.com/jspw/ScrollSense"
  url "https://github.com/jspw/ScrollSense/archive/refs/tags/v1.0.8.tar.gz"
  sha256 "2e5c6624184c8b8a8decc6a6663f07293f6d2f79caeba2a36162cbf70d7a2c2f"
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
    assert_match "1.0.8", shell_output("#{bin}/scrollSense --version")
  end
end
