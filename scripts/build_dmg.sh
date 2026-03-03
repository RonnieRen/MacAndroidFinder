#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/AndroidBridgeApp.xcodeproj"
SCHEME="AndroidBridgeApp"
CONFIG="Release"
BUILD_ROOT="$ROOT_DIR/build"
DERIVED_DATA="$BUILD_ROOT/DerivedData"
SYMROOT="$BUILD_ROOT/Products"
OBJROOT="$BUILD_ROOT/Intermediates.noindex"
APP_NAME="AndroidBridgeApp"
APP_PATH="$SYMROOT/$CONFIG/$APP_NAME.app"
DMG_STAGING="$BUILD_ROOT/dmg_staging"
DMG_PATH="$BUILD_ROOT/$APP_NAME.dmg"

mkdir -p "$BUILD_ROOT"

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -derivedDataPath "$DERIVED_DATA" \
  SYMROOT="$SYMROOT" \
  OBJROOT="$OBJROOT" \
  clean build

if [[ ! -d "$APP_PATH" ]]; then
  echo "Build succeeded but app not found: $APP_PATH" >&2
  exit 1
fi

rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
cp -R "$APP_PATH" "$DMG_STAGING/"

rm -f "$DMG_PATH"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_STAGING" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "DMG created: $DMG_PATH"
