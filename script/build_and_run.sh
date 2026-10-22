#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build"
APP_DIR="$BUILD_DIR/ThreeFingerLookup.app"

swift build --package-path "$ROOT_DIR" -c debug
BIN_DIR="$(swift build --package-path "$ROOT_DIR" --show-bin-path)"
EXECUTABLE="$BIN_DIR/ThreeFingerLookup"
swift "$ROOT_DIR/script/generate_icon.swift" "$ROOT_DIR/Resources/AppIcon.icns"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$EXECUTABLE" "$APP_DIR/Contents/MacOS/ThreeFingerLookup"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$ROOT_DIR/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"

if [[ "${1:-}" == "--verify" ]]; then
  /usr/bin/plutil -lint "$APP_DIR/Contents/Info.plist"
  /usr/bin/file "$APP_DIR/Contents/MacOS/ThreeFingerLookup"
  exit 0
fi

if [[ "${1:-}" == "--debug" || "${1:-}" == "--logs" || "${1:-}" == "--telemetry" ]]; then
  shift
fi

/usr/bin/open -n "$APP_DIR"
