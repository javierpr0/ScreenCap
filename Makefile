# Makefile for ScreenCap App

APP_NAME = ScreenCap
BUNDLE_ID = com.screencap.ScreenCap
VERSION ?= 1.0.0
BUILD_DIR = .build
APP_DIR = $(BUILD_DIR)/$(APP_NAME).app
CONTENTS_DIR = $(APP_DIR)/Contents
MACOS_DIR = $(CONTENTS_DIR)/MacOS
RESOURCES_DIR = $(CONTENTS_DIR)/Resources

# Detect architecture dynamically
ARCH := $(shell uname -m)

.PHONY: all build clean install install-user run debug dist zip lint test notarize help

all: build

# Build the application
build:
	@echo "Building ScreenCap..."
	@swift build -c release
	@echo "Creating application bundle..."
	@mkdir -p $(MACOS_DIR)
	@mkdir -p $(RESOURCES_DIR)
	@cp .build/release/ScreenCap $(MACOS_DIR)/
	@cp ScreenCap.entitlements $(RESOURCES_DIR)/
	@echo "Generating and copying application icon..."
	@if [ ! -f ScreenCap.icns ]; then ./generate-iconset.sh; fi
	@cp ScreenCap.icns $(RESOURCES_DIR)/
	@echo "Copying dependency bundles..."
	@if [ -d .build/$(ARCH)-apple-macosx/release/KeyboardShortcuts_KeyboardShortcuts.bundle ]; then \
		rm -rf $(RESOURCES_DIR)/KeyboardShortcuts_KeyboardShortcuts.bundle; \
		cp -R .build/$(ARCH)-apple-macosx/release/KeyboardShortcuts_KeyboardShortcuts.bundle $(RESOURCES_DIR)/; \
		chmod -R 755 $(RESOURCES_DIR)/KeyboardShortcuts_KeyboardShortcuts.bundle; \
		rm -rf $(APP_DIR)/KeyboardShortcuts_KeyboardShortcuts.bundle; \
		cp -R .build/$(ARCH)-apple-macosx/release/KeyboardShortcuts_KeyboardShortcuts.bundle $(APP_DIR)/; \
		chmod -R 755 $(APP_DIR)/KeyboardShortcuts_KeyboardShortcuts.bundle; \
	fi
	@echo "Creating Info.plist from template..."
	@sed 's/__VERSION__/$(VERSION)/g' Info.plist.template > $(CONTENTS_DIR)/Info.plist
	@echo "Signing the application..."
	@codesign --force --deep --sign - --generate-entitlement-der $(APP_DIR) || true
	@echo "Application compiled successfully in $(APP_DIR)"

# Clean build files
clean:
	@echo "Cleaning build files..."
	@rm -rf $(BUILD_DIR)
	@swift package clean
	@echo "Cleanup completed"

# Install in /Applications
install: build
	@echo "Installing ScreenCap in /Applications..."
	@sudo cp -R $(APP_DIR) /Applications/
	@echo "ScreenCap installed in /Applications"
	@echo "You can run the app from Launchpad or Spotlight"

# Install in user's local directory (no sudo required)
install-user: build
	@echo "Installing ScreenCap in ~/Applications..."
	@mkdir -p ~/Applications
	@cp -R $(APP_DIR) ~/Applications/
	@echo "ScreenCap installed in ~/Applications"
	@echo "You can run the app from Finder > Applications"

# Run the application
run: build
	@echo "Running ScreenCap..."
	@open $(APP_DIR)

# Run in debug mode
debug:
	@echo "Running in debug mode..."
	@swift run

# Run linter
lint:
	@if command -v swiftlint > /dev/null 2>&1; then \
		echo "Running SwiftLint..."; \
		swiftlint lint --quiet; \
	else \
		echo "SwiftLint not installed. Install with: brew install swiftlint"; \
	fi

# Run tests
test:
	@echo "Running tests..."
	@swift test

# Create DMG for distribution
dist: build
	@echo "Creating disk image for distribution..."
	@mkdir -p dist
	@rm -f dist/ScreenCap.dmg
	@rm -rf dist/temp
	@mkdir -p dist/temp
	@cp -R $(APP_DIR) dist/temp/
	@ln -s /Applications dist/temp/Applications
	@hdiutil create -volname "ScreenCap" -srcfolder dist/temp -ov -format UDBZ dist/ScreenCap.dmg
	@rm -rf dist/temp
	@echo "DMG created at dist/ScreenCap.dmg"
	@echo "File size: $$(du -h dist/ScreenCap.dmg | cut -f1)"

# Create ZIP for distribution
zip: build
	@echo "Creating ZIP file for distribution..."
	@mkdir -p dist
	@rm -f dist/ScreenCap.zip
	@cd $(BUILD_DIR) && zip -r ../dist/ScreenCap.zip $(APP_NAME).app
	@echo "ZIP created at dist/ScreenCap.zip"
	@echo "File size: $$(du -h dist/ScreenCap.zip | cut -f1)"

# Notarize the app (requires Apple Developer ID)
notarize: dist
	@echo "=== Notarization ==="
	@echo "To notarize, you need:"
	@echo "  1. An Apple Developer ID certificate"
	@echo "  2. An app-specific password from appleid.apple.com"
	@echo ""
	@echo "Steps:"
	@echo "  1. Replace ad-hoc signing with your Developer ID:"
	@echo "     codesign --force --deep --sign 'Developer ID Application: Your Name' $(APP_DIR)"
	@echo "  2. Submit for notarization:"
	@echo "     xcrun notarytool submit dist/ScreenCap.dmg --apple-id YOUR_ID --team-id YOUR_TEAM --password YOUR_APP_PASSWORD --wait"
	@echo "  3. Staple the ticket:"
	@echo "     xcrun stapler staple dist/ScreenCap.dmg"

# Show help
help:
	@echo "Available commands:"
	@echo "  make build        - Build the application"
	@echo "  make clean        - Clean build files"
	@echo "  make install      - Install in /Applications (requires sudo)"
	@echo "  make install-user - Install in ~/Applications (no sudo)"
	@echo "  make run          - Run the application"
	@echo "  make debug        - Run in debug mode"
	@echo "  make lint         - Run SwiftLint"
	@echo "  make test         - Run unit tests"
	@echo "  make dist         - Create DMG for distribution"
	@echo "  make zip          - Create ZIP for distribution"
	@echo "  make notarize     - Notarization instructions"
	@echo "  make help         - Show this help"
