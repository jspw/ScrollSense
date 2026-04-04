#!/bin/bash
set -e

cd "$(dirname "$0")/.."

swift test 2>&1 | tail -1

echo ""

echo "Building release..."
swift build -c release 2>&1 | tail -1

BINARY=".build/release/scrollSense"
codesign --force --sign - "$BINARY" 2>/dev/null

echo ""
echo "Add this to Accessibility (System Settings -> Privacy & Security -> Accessibility):"
echo "  $(cd "$(dirname "$BINARY")" && pwd)/$(basename "$BINARY")"
echo ""

echo "Run with:"
echo "  $BINARY run --debug"
