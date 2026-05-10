#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-build}"
APP_NAME="ThinkQ"
BUNDLE_ID="com.xavier.thinkq"
MIN_SYSTEM_VERSION="14.0"
DEFAULT_SIGN_IDENTITY="ThinkQ Local Development"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
APP_ICON="$ROOT_DIR/Assets/AppIcon.icns"

cd "$ROOT_DIR"
swift build
BUILD_BINARY="$(swift build --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"
if [[ -f "$APP_ICON" ]]; then
  cp "$APP_ICON" "$APP_RESOURCES/AppIcon.icns"
fi

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>CFBundleURLTypes</key>
  <array>
    <dict>
      <key>CFBundleURLName</key>
      <string>$BUNDLE_ID</string>
      <key>CFBundleURLSchemes</key>
      <array>
        <string>thinkq</string>
      </array>
    </dict>
  </array>
</dict>
</plist>
PLIST

sign_app() {
  local identity="${THINKQ_CODE_SIGN_IDENTITY:-}"
  if [[ -z "$identity" ]]; then
    if /usr/bin/security find-certificate -c "$DEFAULT_SIGN_IDENTITY" "$HOME/Library/Keychains/login.keychain-db" >/dev/null 2>&1; then
      identity="$DEFAULT_SIGN_IDENTITY"
    fi
  fi

  if [[ -n "$identity" ]]; then
    /usr/bin/codesign --force --deep --sign "$identity" --identifier "$BUNDLE_ID" "$APP_BUNDLE"
    echo "Signed $APP_NAME.app with identity: $identity"
  else
    /usr/bin/codesign --force --deep --sign - --identifier "$BUNDLE_ID" "$APP_BUNDLE"
    echo "Signed $APP_NAME.app ad-hoc. For stable Keychain access, run script/install_local_codesign_identity.sh once."
  fi
}

sign_app

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  build|--build)
    echo "Built $APP_BUNDLE"
    ;;
  run)
    pkill -x "$APP_NAME" >/dev/null 2>&1 || true
    open_app
    ;;
  --debug|debug)
    pkill -x "$APP_NAME" >/dev/null 2>&1 || true
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    pkill -x "$APP_NAME" >/dev/null 2>&1 || true
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    pkill -x "$APP_NAME" >/dev/null 2>&1 || true
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    pkill -x "$APP_NAME" >/dev/null 2>&1 || true
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [build|run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
