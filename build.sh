#!/bin/bash
set -e

APP_NAME="CosmicTasks"
BUILD_DIR="$(pwd)/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"

echo "🌌 Building CosmicTasks..."

# Clean previous build
rm -rf "$BUILD_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# Compile all Swift sources into one binary
swiftc \
    -o "$MACOS_DIR/$APP_NAME" \
    -target arm64-apple-macosx14.0 \
    -O \
    Sources/Models/CosmicTask.swift \
    Sources/Helpers/Constants.swift \
    Sources/Models/TaskManager.swift \
    Sources/Scene/StarfieldNode.swift \
    Sources/Scene/PlanetNode.swift \
    Sources/Scene/MeteorNode.swift \
    Sources/Scene/ExplosionEffect.swift \
    Sources/Scene/TaskPopoverNode.swift \
    Sources/Scene/CosmicScene.swift \
    Sources/App/StatusBarController.swift \
    Sources/App/AppDelegate.swift \
    Sources/App/main.swift \
    -framework Cocoa \
    -framework SpriteKit \
    -framework SwiftUI

echo "✅ Compiled binary"

# Create Info.plist
cat > "$CONTENTS/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>CosmicTasks</string>
    <key>CFBundleIdentifier</key>
    <string>com.cosmictasks.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>CosmicTasks</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

echo "✅ Created app bundle at: $APP_BUNDLE"
echo ""
echo "🚀 Launching CosmicTasks..."
echo "   Look for the ✨ icon in your menu bar!"
echo ""

# Launch the app
open "$APP_BUNDLE"
