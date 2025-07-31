#!/bin/bash

# Script to generate iconset from icon.png
set -e  # Stop execution if any command fails

# Verify if the input file exists
if [ ! -f "icon.png" ]; then
    echo "❌ Error: icon.png file not found"
    exit 1
fi

# Verify write permissions in the current directory
if [ ! -w "$(pwd)" ]; then
    echo "❌ Error: You don't have write permissions in the current directory"
    exit 1
fi

echo "🎨 Generating icon set for ScreenCap..."

# Create temporary directory for the iconset
mkdir -p ScreenCap.iconset || { echo "❌ Error: Could not create ScreenCap.iconset directory"; exit 1; }

# Generate all necessary sizes
sips -z 16 16     icon.png --out ScreenCap.iconset/icon_16x16.png || { echo "❌ Error generating 16x16 icon"; exit 1; }
sips -z 32 32     icon.png --out ScreenCap.iconset/icon_16x16@2x.png || { echo "❌ Error generating 16x16@2x icon"; exit 1; }
sips -z 32 32     icon.png --out ScreenCap.iconset/icon_32x32.png || { echo "❌ Error generating 32x32 icon"; exit 1; }
sips -z 64 64     icon.png --out ScreenCap.iconset/icon_32x32@2x.png || { echo "❌ Error generating 32x32@2x icon"; exit 1; }
sips -z 128 128   icon.png --out ScreenCap.iconset/icon_128x128.png || { echo "❌ Error generating 128x128 icon"; exit 1; }
sips -z 256 256   icon.png --out ScreenCap.iconset/icon_128x128@2x.png || { echo "❌ Error generating 128x128@2x icon"; exit 1; }
sips -z 256 256   icon.png --out ScreenCap.iconset/icon_256x256.png || { echo "❌ Error generating 256x256 icon"; exit 1; }
sips -z 512 512   icon.png --out ScreenCap.iconset/icon_256x256@2x.png || { echo "❌ Error generating 256x256@2x icon"; exit 1; }
sips -z 512 512   icon.png --out ScreenCap.iconset/icon_512x512.png || { echo "❌ Error generating 512x512 icon"; exit 1; }
sips -z 1024 1024 icon.png --out ScreenCap.iconset/icon_512x512@2x.png || { echo "❌ Error generating 512x512@2x icon"; exit 1; }

# Verify that iconutil is available
if ! command -v iconutil &> /dev/null; then
    echo "❌ Error: iconutil command is not available"
    exit 1
fi

# Generate .icns file
echo "Generating .icns file..."
iconutil -c icns ScreenCap.iconset || { 
    echo "❌ Error generating .icns file"
    # Check if the output file exists despite the error
    if [ -f "ScreenCap.icns" ]; then
        echo "⚠️ The ScreenCap.icns file exists but may be corrupted"
    fi
    exit 1
}

# Clean up temporary directory
if [ -d "ScreenCap.iconset" ]; then
    rm -rf ScreenCap.iconset || { 
        echo "⚠️ Warning: Could not remove temporary directory"
        # Not a critical error, continuing
    }
fi

echo "✅ ScreenCap.icns file generated successfully"