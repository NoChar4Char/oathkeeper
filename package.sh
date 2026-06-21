#!/bin/bash
set -e

WORKSPACE_DIR="/Users/charlie/oathkeeper"
LOGO_PATH="/Users/charlie/.gemini/antigravity-ide/brain/808203c7-af04-48da-b6ed-184f81853bbf/oathkeeper_logo_1781124723442.png"
APP_DIR="${WORKSPACE_DIR}/Oathkeeper.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
ICONSET_DIR="${WORKSPACE_DIR}/AppIcon.iconset"

echo "=== Oathkeeper Release Packaging ==="

# 1. Compile natively for Apple Silicon (arm64)
echo "Building binary natively for Apple Silicon (arm64)..."
cd "${WORKSPACE_DIR}"
swift build -c release --arch arm64

# 2. Create the App Bundle directory structure
echo "Creating .app bundle structure..."
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# 3. Copy the compiled executable to Contents/MacOS
echo "Copying release binary..."
cp "${WORKSPACE_DIR}/.build/release/Oathkeeper" "${MACOS_DIR}/Oathkeeper"
cp "${WORKSPACE_DIR}/.build/release/OathkeeperDaemon" "${MACOS_DIR}/OathkeeperDaemon"




# 4. Generate the AppIcon.icns from the PNG logo
if [ -f "${LOGO_PATH}" ]; then
    echo "Generating macOS AppIcon.icns from logo..."
    rm -rf "${ICONSET_DIR}"
    mkdir -p "${ICONSET_DIR}"
    
    # Generate all required icon sizes for macOS
    sips -s format png -z 16 16     "${LOGO_PATH}" --out "${ICONSET_DIR}/icon_16x16.png" > /dev/null
    sips -s format png -z 32 32     "${LOGO_PATH}" --out "${ICONSET_DIR}/icon_16x16@2x.png" > /dev/null
    sips -s format png -z 32 32     "${LOGO_PATH}" --out "${ICONSET_DIR}/icon_32x32.png" > /dev/null
    sips -s format png -z 64 64     "${LOGO_PATH}" --out "${ICONSET_DIR}/icon_32x32@2x.png" > /dev/null
    sips -s format png -z 128 128   "${LOGO_PATH}" --out "${ICONSET_DIR}/icon_128x128.png" > /dev/null
    sips -s format png -z 256 256   "${LOGO_PATH}" --out "${ICONSET_DIR}/icon_128x128@2x.png" > /dev/null
    sips -s format png -z 256 256   "${LOGO_PATH}" --out "${ICONSET_DIR}/icon_256x256.png" > /dev/null
    sips -s format png -z 512 512   "${LOGO_PATH}" --out "${ICONSET_DIR}/icon_256x256@2x.png" > /dev/null
    sips -s format png -z 512 512   "${LOGO_PATH}" --out "${ICONSET_DIR}/icon_512x512.png" > /dev/null
    sips -s format png -z 1024 1024 "${LOGO_PATH}" --out "${ICONSET_DIR}/icon_512x512@2x.png" > /dev/null
    
    # Compile the iconset into an .icns file
    iconutil -c icns "${ICONSET_DIR}" -o "${RESOURCES_DIR}/AppIcon.icns"
    rm -rf "${ICONSET_DIR}"
    echo "Successfully generated AppIcon.icns!"
else
    echo "Warning: Logo file not found at ${LOGO_PATH}, skipping icon generation."
fi

# 5. Create Info.plist
echo "Writing Info.plist..."
cat <<EOF > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Oathkeeper</string>
    <key>CFBundleIdentifier</key>
    <string>com.nochar4char.oathkeeper</string>
    <key>CFBundleName</key>
    <string>Oathkeeper</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.4.1</string>
    <key>CFBundleVersion</key>
    <string>1.4.1</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

# 6. Apply Ad-hoc Code Signing
echo "Applying ad-hoc code signature..."
codesign --force --deep --sign - "${APP_DIR}"

# 7. Package into a distribution DMG installer (and clean up ZIP archive)
rm -f "${WORKSPACE_DIR}/Oathkeeper.zip"
echo "Creating DMG Installer volume..."
"${WORKSPACE_DIR}/create_dmg.sh"

echo "=== Packaging Complete! ==="
echo "Application bundle created: ${APP_DIR}"
echo "Distribution installer created: ${WORKSPACE_DIR}/Oathkeeper.dmg"
