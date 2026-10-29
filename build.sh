#!/bin/bash
# Builds PCCat.app — a self-contained macOS app bundle.
# Requires only the Command Line Tools (no Xcode needed).
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="PCCat"
BUILD_DIR=".build/release"
APP_BUNDLE="dist/${APP_NAME}.app"

echo "▸ Building release binary…"
swift build -c release

echo "▸ Assembling ${APP_BUNDLE}…"
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BUILD_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

# Icon: generate a simple cat-paw icon if none exists.
if [ -f "Resources/AppIcon.icns" ]; then
  cp "Resources/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
  ICON_KEY="CFBundleIconFile"
else
  ICON_KEY="CFBundleIconName"
fi

cat > "${APP_BUNDLE}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
    <key>CFBundleExecutable</key><string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key><string>com.pccat.desktop</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>${ICON_KEY}</key><string>AppIcon</string>
    <key>NSHumanReadableCopyright</key><string>PCCat</string>
    <key>LSUIElement</key><false/>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
</dict>
</plist>
PLIST

# Bundle the local illustration animations (cats + flowers) into the app,
# so the illustrated mode works no matter where the .app is launched from.
if [ -d "local/illustrations" ]; then
  mkdir -p "${APP_BUNDLE}/Contents/Resources/illustrations"
  cp -f local/illustrations/*.webp local/illustrations/*.gif "${APP_BUNDLE}/Contents/Resources/illustrations/" 2>/dev/null
  echo "  bundled illustrations"
fi

# Ad-hoc signature so macOS lets it launch without a developer cert.
codesign --force --deep --sign - "${APP_BUNDLE}" 2>/dev/null || echo "  (codesign skipped)"

echo "✓ Done → ${APP_BUNDLE}"
echo "  Open with: open ${APP_BUNDLE}"
