#!/bin/bash
set -e

APP_NAME="CosmicTasks"
BUILD_DIR="$(pwd)/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
DMG_DIR="$BUILD_DIR/dmg"
DMG_NAME="$APP_NAME.dmg"
DMG_PATH="$BUILD_DIR/$DMG_NAME"
VOLUME_NAME="$APP_NAME"

# Step 1: Build the app
echo "🌌 Building $APP_NAME..."
bash build.sh

# Step 2: Verify app bundle exists
if [ ! -d "$APP_BUNDLE" ]; then
    echo "❌ App bundle not found at $APP_BUNDLE"
    exit 1
fi

# Step 3: Prepare DMG staging directory
echo "📦 Preparing DMG contents..."
rm -rf "$DMG_DIR"
mkdir -p "$DMG_DIR"

# Copy app bundle into staging directory
cp -R "$APP_BUNDLE" "$DMG_DIR/"

# Create a symbolic link to /Applications for drag-and-drop install
ln -s /Applications "$DMG_DIR/Applications"

# Step 4: Remove any previous DMG
rm -f "$DMG_PATH"

# Step 5: Create the DMG
echo "💿 Creating DMG..."
hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$DMG_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

# Step 6: Clean up staging directory
rm -rf "$DMG_DIR"

echo ""
echo "✅ DMG created at: $DMG_PATH"
echo "   Size: $(du -h "$DMG_PATH" | cut -f1)"
