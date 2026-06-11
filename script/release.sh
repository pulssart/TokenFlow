#!/usr/bin/env bash
set -euo pipefail

APP_NAME="TokenFlow"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT_DIR/TokenFlow.xcodeproj"
BUILD_DIR="$ROOT_DIR/build-dist"
DIST_DIR="$ROOT_DIR/dist"
IDENTITY="${TOKENFLOW_SIGN_IDENTITY:-Developer ID Application: Adrien DONOT (MKAFV9VL9V)}"
TEAM_ID="${TOKENFLOW_TEAM_ID:-MKAFV9VL9V}"
NOTARY_PROFILE="${TOKENFLOW_NOTARY_PROFILE:-TokenFlow}"

cd "$ROOT_DIR"

clear_bundle_xattrs() {
  local path="$1"
  /usr/bin/xattr -cr "$path" 2>/dev/null || true
  /usr/bin/xattr -dr com.apple.FinderInfo "$path" 2>/dev/null || true
  /usr/bin/xattr -dr 'com.apple.fileprovider.fpfs#P' "$path" 2>/dev/null || true
}

if command -v xcodegen >/dev/null 2>&1; then
  xcodegen generate
elif [[ ! -d "$PROJECT" ]]; then
  echo "TokenFlow.xcodeproj is missing and xcodegen is not installed" >&2
  exit 1
fi

rm -rf "$BUILD_DIR" "$DIST_DIR"
mkdir -p "$DIST_DIR"

xcodebuild \
  -project "$PROJECT" \
  -scheme "$APP_NAME" \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_IDENTITY="$IDENTITY" \
  CODE_SIGN_STYLE=Manual \
  ENABLE_HARDENED_RUNTIME=YES \
  clean build

TARGET_BUILD_DIR="$(xcodebuild -project "$PROJECT" -scheme "$APP_NAME" -configuration Release -derivedDataPath "$BUILD_DIR" -showBuildSettings | awk -F ' = ' '/TARGET_BUILD_DIR/ { print $2; exit }')"
APP_BUNDLE="$TARGET_BUILD_DIR/$APP_NAME.app"

clear_bundle_xattrs "$APP_BUNDLE"
/usr/bin/codesign --force --options runtime --timestamp --sign "$IDENTITY" --entitlements TokenFlowWidgets/TokenFlowWidgets.entitlements "$APP_BUNDLE/Contents/PlugIns/TokenFlowWidgets.appex"
/usr/bin/codesign --force --options runtime --timestamp --sign "$IDENTITY" --entitlements TokenFlowApp/TokenFlow.entitlements "$APP_BUNDLE"
/usr/bin/codesign --verify --deep --strict --verbose=4 "$APP_BUNDLE"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_BUNDLE/Contents/Info.plist")"
DMG_NAME="$APP_NAME-$VERSION.dmg"
DMG="$DIST_DIR/$DMG_NAME"
RW_DMG="$DIST_DIR/rw-$DMG_NAME"
STAGE="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/$APP_NAME-dmg-stage.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT

mkdir -p "$STAGE"
/usr/bin/ditto "$APP_BUNDLE" "$STAGE/$APP_NAME.app"
clear_bundle_xattrs "$STAGE/$APP_NAME.app"
/usr/bin/codesign --verify --deep --strict --verbose=4 "$STAGE/$APP_NAME.app"
ln -s /Applications "$STAGE/Applications"

hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -fs HFS+ -format UDRW "$RW_DMG"
hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG"
rm -f "$RW_DMG"

/usr/bin/codesign --force --timestamp --sign "$IDENTITY" "$DMG"
/usr/bin/codesign --verify --verbose=4 "$DMG"

if [[ "${TOKENFLOW_SKIP_NOTARIZE:-0}" != "1" ]]; then
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG"
  xcrun stapler validate "$DMG"
fi

echo "$DMG"
