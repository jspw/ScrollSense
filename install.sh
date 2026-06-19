#!/usr/bin/env bash
#
# Build, sign, and install scrollSense.
#
# macOS (especially 26+) refuses to persist Accessibility grants for the
# "linker-signed" ad-hoc signature that SwiftPM produces. We re-sign with a
# proper ad-hoc signature so the permission sticks across restarts.
#
set -euo pipefail

DEST="/usr/local/bin/scrollSense"
BIN=".build/release/scrollSense"

echo "==> Building release binary..."
# Scope a git override to this command only: SwiftPM fetches dependencies from
# bare repos, which a global safe.bareRepository=explicit setting would block.
GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.bareRepository GIT_CONFIG_VALUE_0=all \
  swift build -c release

SIGN_ID="ScrollSense Self-Signed"
if security find-identity -v -p codesigning | grep -q "$SIGN_ID"; then
  echo "==> Signing with stable identity: $SIGN_ID"
  codesign --force --sign "$SIGN_ID" --identifier com.scrollsense.daemon "$BIN"
else
  echo "==> No stable identity found; using ad-hoc signature."
  echo "    (Run ./setup-signing.sh once so the Accessibility grant survives rebuilds.)"
  codesign --force --sign - "$BIN"
fi

# Confirm the linker-signed flag is gone.
if codesign -dvvv "$BIN" 2>&1 | grep -q "linker-signed"; then
  echo "ERROR: binary is still linker-signed; Accessibility grant will not persist." >&2
  exit 1
fi

echo "==> Installing to $DEST (may prompt for your password)..."
sudo cp "$BIN" "$DEST"

echo
echo "Installed: $DEST"
echo
echo "Next steps:"
echo "  1. System Settings -> Privacy & Security -> Accessibility"
echo "  2. Add $DEST (press + , then Cmd+Shift+G to paste the path) and enable it."
echo "  3. Run:  scrollSense run --debug"
echo
echo "If you previously added a stale scrollSense entry, remove it first."
