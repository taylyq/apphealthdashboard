#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "=== Building App Health Dashboard ==="

# 1. Compile Swift executable in release mode
echo "Compiling Swift target..."
swift build -c release

# 2. Set up App Bundle directory structure
APP_DIR="AppHealthDashboard.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "Creating App Bundle structure..."
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# 3. Copy compiled executable to App Bundle
echo "Copying executable..."
cp ".build/release/AppHealthDashboard" "$MACOS_DIR/AppHealthDashboard"
chmod +x "$MACOS_DIR/AppHealthDashboard"

# 4. Copy Info.plist
echo "Copying Info.plist..."
cp "Info.plist" "$CONTENTS_DIR/Info.plist"

# 5. Generate Icons if icon.png exists
if [ -f "icon.png" ]; then
    echo "Generating AppIcon.icns from icon.png..."
    ICONSET_DIR="AppIcon.iconset"
    mkdir -p "$ICONSET_DIR"
    
    # Generate all required icon sizes
    sips -s format png -z 16 16     icon.png --out "$ICONSET_DIR/icon_16x16.png" > /dev/null 2>&1
    sips -s format png -z 32 32     icon.png --out "$ICONSET_DIR/icon_16x16@2x.png" > /dev/null 2>&1
    sips -s format png -z 32 32     icon.png --out "$ICONSET_DIR/icon_32x32.png" > /dev/null 2>&1
    sips -s format png -z 64 64     icon.png --out "$ICONSET_DIR/icon_32x32@2x.png" > /dev/null 2>&1
    sips -s format png -z 128 128   icon.png --out "$ICONSET_DIR/icon_128x128.png" > /dev/null 2>&1
    sips -s format png -z 256 256   icon.png --out "$ICONSET_DIR/icon_128x128@2x.png" > /dev/null 2>&1
    sips -s format png -z 256 256   icon.png --out "$ICONSET_DIR/icon_256x256.png" > /dev/null 2>&1
    sips -s format png -z 512 512   icon.png --out "$ICONSET_DIR/icon_256x256@2x.png" > /dev/null 2>&1
    sips -s format png -z 512 512   icon.png --out "$ICONSET_DIR/icon_512x512.png" > /dev/null 2>&1
    sips -s format png -z 1024 1024 icon.png --out "$ICONSET_DIR/icon_512x512@2x.png" > /dev/null 2>&1
    
    # Convert iconset to icns
    iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns"
    
    # Clean up iconset folder
    rm -rf "$ICONSET_DIR"
    echo "AppIcon.icns created successfully."
else
    echo "Warning: icon.png not found. App will build without custom icon."
fi

# 6. Touch bundle to force Finder update
touch "$APP_DIR"

echo "=== Build Completed Successfully! ==="
echo "App bundle: $APP_DIR"
