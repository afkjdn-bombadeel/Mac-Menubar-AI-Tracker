#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MacMenubarAITracker"
BUNDLE_ID="local.mac-menubar-ai-tracker"
VERSION="${1:-0.1.0}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_DIR="$ROOT_DIR/dist/release"
APP_BUNDLE="$RELEASE_DIR/$APP_NAME.app"
EXECUTABLE="$ROOT_DIR/.build/release/$APP_NAME"
ZIP_PATH="$RELEASE_DIR/$APP_NAME-$VERSION.zip"

cd "$ROOT_DIR"

swift build -c release

rm -rf "$APP_BUNDLE" "$ZIP_PATH" "$ZIP_PATH.sha256"
mkdir -p "$APP_BUNDLE/Contents/MacOS"

cp "$EXECUTABLE" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
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
    <key>CFBundleDisplayName</key>
    <string>Mac Menubar AI Tracker</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright (C) 2026 @tombombadeel</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

if command -v xattr >/dev/null 2>&1; then
    xattr -cr "$APP_BUNDLE"
fi

if command -v codesign >/dev/null 2>&1; then
    codesign --force --deep --sign - "$APP_BUNDLE"
    if command -v xattr >/dev/null 2>&1; then
        xattr -cr "$APP_BUNDLE"
    fi
    codesign --verify --deep --strict "$APP_BUNDLE"
fi

(
    cd "$RELEASE_DIR"
    ditto -c -k --norsrc --keepParent "$APP_NAME.app" "$APP_NAME-$VERSION.zip"
    shasum -a 256 "$APP_NAME-$VERSION.zip" > "$APP_NAME-$VERSION.zip.sha256"
)

if command -v xattr >/dev/null 2>&1; then
    xattr -cr "$APP_BUNDLE"
fi

if command -v codesign >/dev/null 2>&1; then
    codesign --verify --deep --strict "$APP_BUNDLE"
fi

echo "Created $ZIP_PATH"
echo "Created $ZIP_PATH.sha256"
