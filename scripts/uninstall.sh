#!/bin/bash
# uninstall.sh — reverses install.sh: removes the app and its Quick Look extension registration.
# Changes on this Mac: deletes /Applications/MarkDwain.app, unregisters the extension, resets Quick Look,
# and (optionally, with --purge) deletes saved preferences and the repo's build/ folder.
set -uo pipefail

APP_NAME="MarkDwain"
EXT_ID="local.markdwain.quicklook"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "==> Quitting $APP_NAME"
osascript -e "tell application \"$APP_NAME\" to quit" >/dev/null 2>&1 || true

echo "==> Unregistering Quick Look extension"
pluginkit -e ignore -i "$EXT_ID" >/dev/null 2>&1 || true
pluginkit -r "/Applications/$APP_NAME.app/Contents/PlugIns/$APP_NAME Quick Look.appex" >/dev/null 2>&1 || true

echo "==> Removing /Applications/$APP_NAME.app"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "/Applications/$APP_NAME.app" >/dev/null 2>&1 || true
rm -rf "/Applications/$APP_NAME.app"

qlmanage -r >/dev/null 2>&1 || true
qlmanage -r cache >/dev/null 2>&1 || true

if [ "${1:-}" = "--purge" ]; then
  echo "==> Purging preferences and build files"
  defaults delete local.markdwain >/dev/null 2>&1 || true
  rm -rf "$ROOT/build" "$ROOT/$APP_NAME.xcodeproj"
fi
echo "==> Done."
