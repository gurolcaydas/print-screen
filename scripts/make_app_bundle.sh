#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="PrintScreenApp"
BUNDLE_NAME="${APP_NAME}.app"
BUILD_BIN="${ROOT_DIR}/.build/release/${APP_NAME}"
DIST_DIR="${ROOT_DIR}/dist"
APP_DIR="${DIST_DIR}/${BUNDLE_NAME}"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
PLIST_PATH="${CONTENTS_DIR}/Info.plist"

cd "${ROOT_DIR}"

echo "Building release binary..."
swift build -c release

if [[ ! -x "${BUILD_BIN}" ]]; then
  echo "Error: release binary not found at ${BUILD_BIN}" >&2
  exit 1
fi

echo "Creating app bundle at ${APP_DIR}"
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}"

cp "${BUILD_BIN}" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"

cat > "${PLIST_PATH}" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDisplayName</key>
  <string>PrintScreenApp</string>
  <key>CFBundleExecutable</key>
  <string>PrintScreenApp</string>
  <key>CFBundleIdentifier</key>
  <string>local.printscreen.app</string>
  <key>CFBundleName</key>
  <string>PrintScreenApp</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

# Ad-hoc sign to reduce launch friction on modern macOS.
if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "${APP_DIR}" >/dev/null 2>&1 || true
fi

echo "Done: ${APP_DIR}"
echo "Open it with: open \"${APP_DIR}\""
