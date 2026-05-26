#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Hunter"
APP_PATH="$ROOT_DIR/build/${APP_NAME}.app"
DMG_PATH="${DMG_PATH:-$ROOT_DIR/build/${APP_NAME}.dmg}"
VOLUME_NAME="${VOLUME_NAME:-Hunter}"

"$ROOT_DIR/scripts/package_app.sh" >/dev/null

STAGING_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

rm -f "$DMG_PATH"
cp -R "$APP_PATH" "$STAGING_DIR/${APP_NAME}.app"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "$DMG_PATH"
