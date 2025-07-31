# Makefile for ScreenCap App

APP_NAME = ScreenCap
BUNDLE_ID = com.screencap.ScreenCap
BUILD_DIR = .build
APP_DIR = $(BUILD_DIR)/$(APP_NAME).app
CONTENTS_DIR = $(APP_DIR)/Contents
MACOS_DIR = $(CONTENTS_DIR)/MacOS
RESOURCES_DIR = $(CONTENTS_DIR)/Resources

.PHONY: all build clean install run help

all: build

# Build the application
build:
	@echo "🔨 Building ScreenCap..."
	@swift build -c release
	@echo "📦 Creating application bundle..."
	@mkdir -p $(MACOS_DIR)
	@mkdir -p $(RESOURCES_DIR)
	@cp .build/release/ScreenCap $(MACOS_DIR)/
	@cp ScreenCap.entitlements $(RESOURCES_DIR)/
	@echo "🎨 Generating and copying application icon..."
	@if [ ! -f ScreenCap.icns ]; then ./generate-iconset.sh; fi
	@cp ScreenCap.icns $(RESOURCES_DIR)/
	@echo "📝 Creating Info.plist..."
	@echo '<?xml version="1.0" encoding="UTF-8"?>' > $(CONTENTS_DIR)/Info.plist
	@echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' >> $(CONTENTS_DIR)/Info.plist
	@echo '<plist version="1.0">' >> $(CONTENTS_DIR)/Info.plist
	@echo '<dict>' >> $(CONTENTS_DIR)/Info.plist
	@echo '	<key>CFBundleExecutable</key>' >> $(CONTENTS_DIR)/Info.plist
	@echo '	<string>$(APP_NAME)</string>' >> $(CONTENTS_DIR)/Info.plist
	@echo '	<key>CFBundleIdentifier</key>' >> $(CONTENTS_DIR)/Info.plist
	@echo '	<string>$(BUNDLE_ID)</string>' >> $(CONTENTS_DIR)/Info.plist
	@echo '	<key>CFBundleName</key>' >> $(CONTENTS_DIR)/Info.plist
	@echo '	<string>$(APP_NAME)</string>' >> $(CONTENTS_DIR)/Info.plist
	@echo '	<key>CFBundleVersion</key>' >> $(CONTENTS_DIR)/Info.plist
	@echo '	<string>1.0</string>' >> $(CONTENTS_DIR)/Info.plist
	@echo '	<key>CFBundleShortVersionString</key>' >> $(CONTENTS_DIR)/Info.plist
	@echo '	<string>1.0</string>' >> $(CONTENTS_DIR)/Info.plist
	@echo '	<key>CFBundleIconFile</key>' >> $(CONTENTS_DIR)/Info.plist
	@echo '	<string>ScreenCap</string>' >> $(CONTENTS_DIR)/Info.plist
	@echo '	<key>CFBundlePackageType</key>' >> $(CONTENTS_DIR)/Info.plist
	@echo '	<string>APPL</string>' >> $(CONTENTS_DIR)/Info.plist
	@echo '	<key>LSMinimumSystemVersion</key>' >> $(CONTENTS_DIR)/Info.plist
	@echo '	<string>14.0</string>' >> $(CONTENTS_DIR)/Info.plist
	@echo '	<key>LSUIElement</key>' >> $(CONTENTS_DIR)/Info.plist
	@echo '	<true/>' >> $(CONTENTS_DIR)/Info.plist
	@echo '	<key>NSHighResolutionCapable</key>' >> $(CONTENTS_DIR)/Info.plist
	@echo '	<true/>' >> $(CONTENTS_DIR)/Info.plist
	@echo '	<key>NSSupportsAutomaticGraphicsSwitching</key>' >> $(CONTENTS_DIR)/Info.plist
	@echo '	<true/>' >> $(CONTENTS_DIR)/Info.plist
	@echo '	<key>NSCameraUsageDescription</key>' >> $(CONTENTS_DIR)/Info.plist
	@echo '	<string>ScreenCap needs access to take screenshots.</string>' >> $(CONTENTS_DIR)/Info.plist
	@echo '	<key>NSScreenCaptureDescription</key>' >> $(CONTENTS_DIR)/Info.plist
	@echo '	<string>ScreenCap needs access to take screenshots.</string>' >> $(CONTENTS_DIR)/Info.plist
	@echo '</dict>' >> $(CONTENTS_DIR)/Info.plist
	@echo '</plist>' >> $(CONTENTS_DIR)/Info.plist
	@echo "🔐 Signing the application..."
	@codesign --force --deep --sign - $(APP_DIR)
	@echo "✅ Application compiled successfully in $(APP_DIR)"

# Clean build files
clean:
	@echo "🧹 Cleaning build files..."
	@rm -rf $(BUILD_DIR)
	@swift package clean
	@echo "✅ Cleanup completed"

# Install in /Applications
install: build
	@echo "📲 Installing ScreenCap in /Applications..."
	@sudo cp -R $(APP_DIR) /Applications/
	@echo "✅ ScreenCap installed in /Applications"
	@echo "💡 You can run the app from Launchpad or Spotlight"

# Install in user's local directory (no sudo required)
install-user: build
	@echo "📲 Installing ScreenCap in ~/Applications..."
	@mkdir -p ~/Applications
	@cp -R $(APP_DIR) ~/Applications/
	@echo "✅ ScreenCap installed in ~/Applications"
	@echo "💡 You can run the app from Finder > Applications"

# Run the application
run: build
	@echo "🚀 Running ScreenCap..."
	@open $(APP_DIR)

# Run in debug mode
debug:
	@echo "🐛 Running in debug mode..."
	@swift run

# Create DMG for distribution
dist: build
	@echo "📦 Creating disk image for distribution..."
	@mkdir -p dist
	@rm -f dist/ScreenCap.dmg
	@rm -rf dist/temp
	@mkdir -p dist/temp
	@cp -R $(APP_DIR) dist/temp/
	@ln -s /Applications dist/temp/Applications
	@hdiutil create -volname "ScreenCap" -srcfolder dist/temp -ov -format UDBZ dist/ScreenCap.dmg
	@rm -rf dist/temp
	@echo "✅ DMG created at dist/ScreenCap.dmg"
	@echo "📏 File size: $$(du -h dist/ScreenCap.dmg | cut -f1)"

# Create ZIP for distribution
zip: build
	@echo "🗜️ Creating ZIP file for distribution..."
	@mkdir -p dist
	@rm -f dist/ScreenCap.zip
	@cd $(BUILD_DIR) && zip -r ../dist/ScreenCap.zip $(APP_NAME).app
	@echo "✅ ZIP created at dist/ScreenCap.zip"
	@echo "📏 File size: $$(du -h dist/ScreenCap.zip | cut -f1)"

# Show help
help:
	@echo "Available commands:"
	@echo "  make build       - Build the application"
	@echo "  make clean       - Clean build files"
	@echo "  make install     - Install in /Applications (requires sudo)"
	@echo "  make install-user - Install in ~/Applications (no sudo)"
	@echo "  make run         - Run the application"
	@echo "  make debug       - Run in debug mode"
	@echo "  make dist        - Create DMG for distribution"
	@echo "  make zip         - Create ZIP for distribution"
	@echo "  make help        - Show this help"