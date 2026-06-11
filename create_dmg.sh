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

# 3. Create a symlink to Applications directory
echo "Creating symlink to /Applications..."
ln -s /Applications "${TEMP_DIR}/Applications"

# 4. Generate the DMG image
echo "Building read-only DMG volume..."
hdiutil create -volname "Oathkeeper" -srcfolder "${TEMP_DIR}" -ov -format UDZO "${DMG_PATH}"

# 5. Clean up temporary directories
rm -rf "${TEMP_DIR}"

echo "=== DMG Creation Complete! ==="
echo "DMG created at: ${DMG_PATH}"
