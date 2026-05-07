#!/usr/bin/env bash
set -euo pipefail

APP_NAME="ThinkQ"
VERSION="${THINKQ_RELEASE_VERSION:-0.1.0-wip}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
ZIP_PATH="$DIST_DIR/$APP_NAME-$VERSION-macos.zip"

"$ROOT_DIR/script/build_app.sh"

rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"

echo "Created $ZIP_PATH"
