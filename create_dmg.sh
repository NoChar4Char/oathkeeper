#!/bin/bash
set -e

WORKSPACE_DIR="/Users/charlie/oathkeeper"
APP_PATH="${WORKSPACE_DIR}/Oathkeeper.app"
DMG_PATH="${WORKSPACE_DIR}/Oathkeeper.dmg"
TEMP_DIR="${WORKSPACE_DIR}/dmg_temp"

echo "=== Creating Oathkeeper DMG Installer ==="

# 1. Clean up old artifacts
rm -rf "${TEMP_DIR}"
rm -f "${DMG_PATH}"

# 2. Build template folder
mkdir -p "${TEMP_DIR}"
echo "Copying app to temporary folder..."
cp -R "${APP_PATH}" "${TEMP_DIR}/"

# 3. Generate the DMG image using create-dmg bash script
echo "Building custom DMG volume with create-dmg..."
"${WORKSPACE_DIR}/create-dmg/create-dmg" \
  --volname "Oathkeeper Installer App" \
  --window-pos 200 120 \
  --window-size 800 400 \
  --icon-size 128 \
  --icon "Oathkeeper.app" 200 190 \
  --hide-extension "Oathkeeper.app" \
  --app-drop-link 600 190 \
  --background "${WORKSPACE_DIR}/dmg_background_custom_2x.png" \
  "${DMG_PATH}" \
  "${TEMP_DIR}"

# 4. Clean up temporary directories
rm -rf "${TEMP_DIR}"

echo "=== DMG Creation Complete! ==="
echo "DMG created at: ${DMG_PATH}"
