#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/ThreeFingerLookup.app"
ARCHIVE_PATH="$DIST_DIR/ThreeFingerLookup-macOS-arm64.zip"
DMG_PATH="$DIST_DIR/ThreeFingerLookup-macOS-arm64.dmg"
SWIFTPM_FLAGS=()
SWIFTPM_FLAGS+=(--manifest-cache local)

if [[ "${THREEFINGER_DISABLE_SWIFTPM_SANDBOX:-0}" == "1" ]]; then
  SWIFTPM_FLAGS+=(--disable-sandbox -debug-info-format none)
fi
if [[ -n "${THREEFINGER_SWIFTPM_SCRATCH_PATH:-}" ]]; then
  SWIFTPM_FLAGS+=(--scratch-path "$THREEFINGER_SWIFTPM_SCRATCH_PATH")
fi

mkdir -p "$DIST_DIR"
rm -rf "$APP_DIR" "$ARCHIVE_PATH" "$DMG_PATH"

swift build --package-path "$ROOT_DIR" -c release "${SWIFTPM_FLAGS[@]}"
BIN_DIR="$(swift build --package-path "$ROOT_DIR" -c release "${SWIFTPM_FLAGS[@]}" --show-bin-path)"
EXECUTABLE="$BIN_DIR/ThreeFingerLookup"
if [[ ! -f "$ROOT_DIR/Resources/AppIcon.icns" ]]; then
  swift "$ROOT_DIR/script/generate_icon.swift" "$ROOT_DIR/Resources/AppIcon.icns"
fi

mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$EXECUTABLE" "$APP_DIR/Contents/MacOS/ThreeFingerLookup"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$ROOT_DIR/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"

/usr/bin/codesign --force --deep --sign - --timestamp=none "$APP_DIR"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_DIR"
/usr/bin/plutil -lint "$APP_DIR/Contents/Info.plist"
/usr/bin/file "$APP_DIR/Contents/MacOS/ThreeFingerLookup"

/usr/bin/ditto -c -k --keepParent "$APP_DIR" "$ARCHIVE_PATH"

if command -v hdiutil >/dev/null 2>&1; then
  STAGE_DIR="$DIST_DIR/.stage"
  mkdir -p "$STAGE_DIR"
  cp -R "$APP_DIR" "$STAGE_DIR/"
  ln -s /Applications "$STAGE_DIR/Applications"
  if ! hdiutil create -quiet -volname "三指查词" -srcfolder "$STAGE_DIR" -ov -format UDZO "$DMG_PATH"; then
    rm -f "$DMG_PATH"
    echo "DMG creation failed; the app bundle and ZIP are still available." >&2
  fi
  rm -rf "$STAGE_DIR"
fi

echo "App: $APP_DIR"
echo "Zip: $ARCHIVE_PATH"
if [[ -f "$DMG_PATH" ]]; then
  echo "DMG: $DMG_PATH"
fi
