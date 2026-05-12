#!/usr/bin/env bash
set -euo pipefail

APP_NAME="iThinkQ"
BUNDLE_ID="com.xavier.ithinkq"
APP_PATH="/Applications/$APP_NAME.app"
OLD_APP_PATHS=(
  "/Applications/ThinkQ.app"
  "/Applications/IThinkQ.app"
)
KEYCHAIN_ACCOUNT="thinq-personal-access-token"
APPLICATION_SUPPORT="$HOME/Library/Application Support/$APP_NAME"
CACHE_PATH="$HOME/Library/Caches/$BUNDLE_ID"
PREFERENCES_PATH="$HOME/Library/Preferences/$BUNDLE_ID.plist"

remove_quick_action_apps() {
  local app_path script
  find /Applications -maxdepth 1 -type d -name 'Turn O*.app' -print0 | while IFS= read -r -d '' app_path; do
    if script="$(/usr/bin/osadecompile "$app_path" 2>/dev/null)"; then
      case "$script" in
        *"/Applications/iThinkQ.app/Contents/Helpers/iThinkQQuickAction"*|\
        *"/Applications/IThinkQ.app/Contents/Helpers/IThinkQQuickAction"*|\
        *"/Applications/ThinkQ.app/Contents/Helpers/ThinkQQuickAction"*)
          rm -rf "$app_path"
          echo "Removed $app_path"
          ;;
      esac
    fi
  done
}

unregister_login_item() {
  if [[ -d "$APP_PATH" ]]; then
    /usr/bin/open -gj -a "$APP_PATH" --args --unregister-login-item >/dev/null 2>&1 || true
    sleep 1
  fi
}

unregister_login_item
/usr/bin/pkill -x "$APP_NAME" >/dev/null 2>&1 || true

remove_quick_action_apps

/usr/bin/security delete-generic-password -s "$BUNDLE_ID" -a "$KEYCHAIN_ACCOUNT" >/dev/null 2>&1 || true
/usr/bin/defaults delete "$BUNDLE_ID" >/dev/null 2>&1 || true
rm -rf "$APPLICATION_SUPPORT" "$CACHE_PATH" "$PREFERENCES_PATH"

if [[ -d "$APP_PATH" ]]; then
  rm -rf "$APP_PATH"
  echo "Removed $APP_PATH"
fi

for old_path in "${OLD_APP_PATHS[@]}"; do
  if [[ -d "$old_path" ]]; then
    rm -rf "$old_path"
    echo "Removed $old_path"
  fi
done

/usr/bin/mdimport /Applications >/dev/null 2>&1 || true

echo "$APP_NAME uninstall cleanup complete."
