#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-debug}"
APP_NAME="Hunter"
BUILD_DIR="$ROOT_DIR/.build/${CONFIGURATION}"
APP_DIR="$ROOT_DIR/build/${APP_NAME}.app"

cd "$ROOT_DIR"
swift build -c "$CONFIGURATION"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BUILD_DIR/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"

for resource_path in \
  "$BUILD_DIR/${APP_NAME}_${APP_NAME}.resources" \
  "$BUILD_DIR/${APP_NAME}_${APP_NAME}.bundle" \
  "$BUILD_DIR/${APP_NAME}.resources" \
  "$BUILD_DIR/${APP_NAME}.bundle"; do
  if [[ -e "$resource_path" ]]; then
    cp -R "$resource_path" "$APP_DIR/Contents/Resources/"
  fi
done

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>zh_CN</string>
  <key>CFBundleExecutable</key>
  <string>Hunter</string>
  <key>CFBundleIdentifier</key>
  <string>com.hunter.focus</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Hunter</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSAppleEventsUsageDescription</key>
  <string>Hunter needs browser automation permission to read the active Chrome or Safari URL for user-configured blacklist rules.</string>
  <key>NSMicrophoneUsageDescription</key>
  <string>Hunter needs microphone access for push-to-talk voice commands and replies.</string>
</dict>
</plist>
PLIST

if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$APP_DIR" >/dev/null
fi

echo "$APP_DIR"
