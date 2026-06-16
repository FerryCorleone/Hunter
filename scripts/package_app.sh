#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-release}"
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

ICON_SOURCE="$ROOT_DIR/Sources/Hunter/Resources/hunter-sunglasses-icon.png"
if [[ -f "$ICON_SOURCE" ]] && command -v sips >/dev/null 2>&1 && command -v iconutil >/dev/null 2>&1; then
  ICONSET_DIR="$APP_DIR/Contents/Resources/AppIcon.iconset"
  TMP_ICON_DIR="$(mktemp -d)"
  rm -rf "$ICONSET_DIR"
  mkdir -p "$ICONSET_DIR"
  for size in 16 32 128 256 512; do
    for scale in 1 2; do
      pixels=$((size * scale))
      scaled="$TMP_ICON_DIR/icon-${pixels}.png"
      if [[ "$scale" -eq 1 ]]; then
        output="$ICONSET_DIR/icon_${size}x${size}.png"
      else
        output="$ICONSET_DIR/icon_${size}x${size}@2x.png"
      fi
      sips -Z "$pixels" "$ICON_SOURCE" --out "$scaled" >/dev/null 2>&1
      sips --padToHeightWidth "$pixels" "$pixels" --padColor FFFFFF "$scaled" --out "$output" >/dev/null 2>&1
    done
  done
  iconutil -c icns "$ICONSET_DIR" -o "$APP_DIR/Contents/Resources/AppIcon.icns"
  rm -rf "$ICONSET_DIR" "$TMP_ICON_DIR"
fi

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
  <string>监管者</string>
  <key>CFBundleDisplayName</key>
  <string>监管者</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSAppleEventsUsageDescription</key>
  <string>监管者需要浏览器自动化权限，用于读取当前 Chrome 或 Safari 标签页 URL 并匹配用户配置的黑名单规则。</string>
  <key>NSMicrophoneUsageDescription</key>
  <string>监管者需要麦克风权限，用于按键说话、语音命令和语音回击。</string>
</dict>
</plist>
PLIST

if command -v codesign >/dev/null 2>&1; then
  CODESIGN_IDENTITY="${CODESIGN_IDENTITY:-}"
  if [[ -z "$CODESIGN_IDENTITY" ]] && command -v security >/dev/null 2>&1; then
    CODESIGN_IDENTITY="$(
      security find-identity -v -p codesigning 2>/dev/null \
        | sed -n 's/.*"\(Apple Development:[^"]*\)".*/\1/p' \
        | head -n 1
    )"
  fi
  CODESIGN_IDENTITY="${CODESIGN_IDENTITY:--}"
  codesign --force --deep --sign "$CODESIGN_IDENTITY" "$APP_DIR" >/dev/null
fi

echo "$APP_DIR"
