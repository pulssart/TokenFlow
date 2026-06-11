#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="TokenFlow"
BUNDLE_ID="com.adriendonot.TokenFlow"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
PROJECT="$ROOT_DIR/TokenFlow.xcodeproj"
INSTALL_DIR="$HOME/Applications"
INSTALLED_APP="$INSTALL_DIR/$APP_NAME.app"
WIDGET_BUNDLE_ID="com.adriendonot.TokenFlow.widgets"

cd "$ROOT_DIR"

if command -v xcodegen >/dev/null 2>&1; then
  xcodegen generate
elif [[ ! -d "$PROJECT" ]]; then
  echo "TokenFlow.xcodeproj is missing and xcodegen is not installed" >&2
  exit 1
fi

pkill -x "$APP_NAME" >/dev/null 2>&1 || true
rm -rf "$BUILD_DIR/Build/Products/Debug/$APP_NAME.app"

xcodebuild \
  -project "$PROJECT" \
  -scheme "$APP_NAME" \
  -configuration Debug \
  -derivedDataPath "$BUILD_DIR" \
  clean build

TARGET_BUILD_DIR="$(xcodebuild -project "$PROJECT" -scheme "$APP_NAME" -configuration Debug -derivedDataPath "$BUILD_DIR" -showBuildSettings | awk -F ' = ' '/TARGET_BUILD_DIR/ { print $2; exit }')"
APP_BUNDLE="$TARGET_BUILD_DIR/$APP_NAME.app"

install_app() {
  mkdir -p "$INSTALL_DIR"
  if [[ -d "$INSTALLED_APP" ]]; then
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "$INSTALLED_APP" >/dev/null 2>&1 || true
  fi
  rm -rf "$INSTALLED_APP"
  /usr/bin/ditto "$APP_BUNDLE" "$INSTALLED_APP"
  /usr/bin/touch "$INSTALLED_APP" "$INSTALLED_APP/Contents/Info.plist" "$INSTALLED_APP/Contents/Resources/TokenFlowIcon.icns"
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f -R -trusted "$INSTALLED_APP"

  if [[ -d "$INSTALLED_APP/Contents/PlugIns/TokenFlowWidgets.appex" ]]; then
    /usr/bin/pluginkit -a "$INSTALLED_APP/Contents/PlugIns/TokenFlowWidgets.appex" >/dev/null 2>&1 || true
    /usr/bin/pluginkit -e use -i "$WIDGET_BUNDLE_ID" >/dev/null 2>&1 || true
  fi
}

open_app() {
  install_app
  /usr/bin/open -n "$INSTALLED_APP"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 2
    pgrep -x "$APP_NAME" >/dev/null
    /usr/bin/pluginkit -m -A -i "$WIDGET_BUNDLE_ID" | grep "$WIDGET_BUNDLE_ID" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
