#!/bin/bash

# Distribution script for ScreenCap
# This script creates a completely standalone version of the application

# Get version from git tag or use default
VERSION=${1:-$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo "1.0.0")}

echo "🚀 Starting distribution process for ScreenCap v$VERSION..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Verify we are in the correct directory
if [ ! -f "Package.swift" ]; then
    echo -e "${RED}Error: This script must be run from the project root directory${NC}"
    exit 1
fi

# Clean previous builds
echo "🧹 Cleaning previous builds..."
make clean

# Compile in release mode with optimizations
echo "🔨 Compiling application in release mode..."
swift build -c release -Xswiftc -O

# Create the application bundle with version
echo "📦 Creating application bundle..."
VERSION=$VERSION make build

# Verify the application compiled correctly
if [ ! -d ".build/ScreenCap.app" ]; then
    echo -e "${RED}Error: The application did not compile correctly${NC}"
    exit 1
fi

# Create distribution directory
echo "📁 Preparing distribution directory..."
rm -rf dist
mkdir -p dist

# Option 1: Create DMG
echo "💿 Creating disk image (DMG)..."
mkdir -p dist/dmg-temp
cp -R .build/ScreenCap.app dist/dmg-temp/
ln -s /Applications dist/dmg-temp/Applications

# Create README for the DMG
cat > dist/dmg-temp/README.txt << EOF
ScreenCap - Screenshot capture tool for macOS

INSTALLATION:
1. Drag ScreenCap.app to the Applications folder
2. The first time you run the application, macOS will request permissions
3. Go to System Settings > Privacy & Security > Privacy > Screen Recording
4. Check the box next to ScreenCap

USAGE:
- The application runs in the menu bar (top right)
- Click the camera icon to see options
- Keyboard shortcuts:
  • ⌘⇧1: Full screen capture
  • ⌘⇧2: Selection capture
  • ⌘⇧3: Window capture

Enjoy using ScreenCap!
EOF

# Create the DMG
hdiutil create -volname "ScreenCap" -srcfolder dist/dmg-temp -ov -format UDBZ dist/ScreenCap.dmg
rm -rf dist/dmg-temp

# Option 2: Create ZIP
echo "🗜️ Creating ZIP file..."
cd .build
zip -r ../dist/ScreenCap.zip ScreenCap.app -x "*.DS_Store"
cd ..

# Create instructions file
cat > dist/INSTALLATION_INSTRUCTIONS.txt << EOF
INSTALLATION INSTRUCTIONS - ScreenCap

=== IMPORTANT ===
The first time you run ScreenCap, macOS will show security warnings.
This is normal for applications downloaded from the Internet.

=== INSTALLATION STEPS ===

1. EXTRACT (if you downloaded the ZIP):
   - Double-click on ScreenCap.zip
   - ScreenCap.app will be created

2. INSTALL:
   - Drag ScreenCap.app to your Applications folder

3. FIRST RUN:
   - Right-click on ScreenCap.app
   - Select "Open"
   - A security warning will appear
   - Click "Open" again

4. REQUIRED PERMISSIONS:
   - Go to: System Settings > Privacy & Security
   - Select the "Privacy" tab
   - In the left list, select "Screen Recording"
   - Check the box next to ScreenCap
   - You may need to restart the application

=== TROUBLESHOOTING ===

If macOS says "ScreenCap is damaged":
1. Open Terminal
2. Run: xattr -cr /Applications/ScreenCap.app
3. Try opening the application again

If keyboard shortcuts don't work:
1. Go to: System Settings > Privacy & Security > Privacy > Accessibility
2. Add ScreenCap to the list and check the box

=== UNINSTALLATION ===
1. Drag ScreenCap.app from Applications to Trash
2. Empty Trash

Enjoy using ScreenCap!
EOF

# Show build information
echo ""
echo -e "${GREEN}✅ Distribution completed successfully!${NC}"
echo ""
echo "📦 Files created:"
echo "  - dist/ScreenCap.dmg ($(du -h dist/ScreenCap.dmg | cut -f1))"
echo "  - dist/ScreenCap.zip ($(du -h dist/ScreenCap.zip | cut -f1))"
echo "  - dist/INSTALLATION_INSTRUCTIONS.txt"
echo ""
echo -e "${YELLOW}📋 Build information:${NC}"
echo "  - Version: $VERSION"
echo "  - Architecture: $(uname -m)"
echo "  - Minimum macOS version: 14.0"
echo "  - Swift version: $(swift --version | head -n 1)"
echo ""
echo -e "${YELLOW}🔐 Code signing:${NC}"
echo "  - The application is signed locally (ad-hoc)"
echo "  - Users will see security warnings on first run"
echo "  - For distribution without warnings, you need:"
echo "    • An Apple Developer account (\$99/year)"
echo "    • Sign with a valid certificate"
echo "    • Notarize the application with Apple"
echo ""
echo "📨 Files are ready to share in the 'dist/' folder"