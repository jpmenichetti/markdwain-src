#!/bin/bash
# install.sh — builds MarkDwain (Release, universal) and installs it, plus its Quick Look extension.
# Run from anywhere:  scripts/install.sh
# Changes on this Mac: creates build/ and MarkDwain.xcodeproj in the repo; replaces /Applications/MarkDwain.app;
# registers the app with Launch Services; enables the Quick Look extension; resets the Quick Look cache.
set -euo pipefail

APP_NAME="MarkDwain"
EXT_ID="local.markdwain.quicklook"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
fail() { echo "ERROR: $1" >&2; exit 1; }

# 1. Full Xcode (not just Command Line Tools) is required to build apps and app extensions.
echo "==> Checking Xcode"
xcodebuild -version >/dev/null 2>&1 || fail "Full Xcode is required. Install it from the App Store, open it once to accept the license, then run: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"

# 2. XcodeGen turns project.yml into the Xcode project. Install through Homebrew when missing.
echo "==> Checking XcodeGen"
if ! command -v xcodegen >/dev/null 2>&1; then
  command -v brew >/dev/null 2>&1 || fail "XcodeGen is missing and Homebrew is not installed. Install Homebrew from https://brew.sh, then run this script again."
  echo "    Installing XcodeGen with Homebrew..."
  brew install xcodegen
fi

# 3. Generate MarkDwain.xcodeproj (a build artifact, git-ignored).
echo "==> Generating Xcode project"
xcodegen generate --quiet

# 4. Release build. Ad-hoc signature ("Sign to Run Locally", set in project.yml); both CPU types so
#    the same build works on Apple Silicon and Intel Macs.
echo "==> Building (this takes a minute)"
xcodebuild -project "$APP_NAME.xcodeproj" -scheme "$APP_NAME" -configuration Release \
  -derivedDataPath build ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO -quiet build \
  || fail "The build failed. Run the command from docs/DEVELOPMENT.md without -quiet to see why."
BUILT="build/Build/Products/Release/$APP_NAME.app"
[ -d "$BUILT" ] || fail "Build finished but $BUILT was not found."

# 5. Copy to /Applications. Quit a running copy first; ditto preserves the code signature.
echo "==> Installing to /Applications"
osascript -e "tell application \"$APP_NAME\" to quit" >/dev/null 2>&1 || true
rm -rf "/Applications/$APP_NAME.app"
ditto "$BUILT" "/Applications/$APP_NAME.app"

# 6. Tell Launch Services about the app (document types, icon) and register the extension with PlugInKit.
echo "==> Registering with macOS"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "/Applications/$APP_NAME.app"
pluginkit -a "/Applications/$APP_NAME.app/Contents/PlugIns/$APP_NAME Quick Look.appex" || true
pluginkit -e use -i "$EXT_ID" || echo "    (could not enable the extension automatically; see README > Quick Look)"

# 7. Make Quick Look pick up the new extension.
qlmanage -r >/dev/null 2>&1 || true
qlmanage -r cache >/dev/null 2>&1 || true

echo "==> Done. $APP_NAME is in /Applications."
echo "    To make it the default for .md files: select a .md file in Finder, press Cmd+I, choose $APP_NAME under 'Open with', click 'Change All...'."
