# Makefile para ScreenCap App

APP_NAME = ScreenCap
BUNDLE_ID = com.screencap.ScreenCap
BUILD_DIR = .build
APP_DIR = $(BUILD_DIR)/$(APP_NAME).app
CONTENTS_DIR = $(APP_DIR)/Contents
MACOS_DIR = $(CONTENTS_DIR)/MacOS
RESOURCES_DIR = $(CONTENTS_DIR)/Resources

.PHONY: all build clean install run help

all: build

# Compilar la aplicación
build:
	@echo "🔨 Compilando ScreenCap..."
	@swift build -c release
	@echo "📦 Creando bundle de aplicación..."
	@mkdir -p $(MACOS_DIR)
	@mkdir -p $(RESOURCES_DIR)
	@cp .build/release/ScreenCap $(MACOS_DIR)/
	@cp ScreenCap.entitlements $(RESOURCES_DIR)/
	@echo "🎨 Generando y copiando icono de la aplicación..."
	@if [ ! -f ScreenCap.icns ]; then ./generate-iconset.sh; fi
	@cp ScreenCap.icns $(RESOURCES_DIR)/
	@echo "📝 Creando Info.plist..."
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
	@echo '	<string>ScreenCap necesita acceso para tomar capturas de pantalla.</string>' >> $(CONTENTS_DIR)/Info.plist
	@echo '	<key>NSScreenCaptureDescription</key>' >> $(CONTENTS_DIR)/Info.plist
	@echo '	<string>ScreenCap necesita acceso para tomar capturas de pantalla.</string>' >> $(CONTENTS_DIR)/Info.plist
	@echo '</dict>' >> $(CONTENTS_DIR)/Info.plist
	@echo '</plist>' >> $(CONTENTS_DIR)/Info.plist
	@echo "🔐 Firmando la aplicación..."
	@codesign --force --deep --sign - $(APP_DIR)
	@echo "✅ Aplicación compilada exitosamente en $(APP_DIR)"

# Limpiar archivos de compilación
clean:
	@echo "🧹 Limpiando archivos de compilación..."
	@rm -rf $(BUILD_DIR)
	@swift package clean
	@echo "✅ Limpieza completada"

# Instalar en /Applications
install: build
	@echo "📲 Instalando ScreenCap en /Applications..."
	@sudo cp -R $(APP_DIR) /Applications/
	@echo "✅ ScreenCap instalado en /Applications"
	@echo "💡 Puedes ejecutar la app desde Launchpad o Spotlight"

# Instalar en el directorio local del usuario (no requiere sudo)
install-user: build
	@echo "📲 Instalando ScreenCap en ~/Applications..."
	@mkdir -p ~/Applications
	@cp -R $(APP_DIR) ~/Applications/
	@echo "✅ ScreenCap instalado en ~/Applications"
	@echo "💡 Puedes ejecutar la app desde Finder > Applications"

# Ejecutar la aplicación
run: build
	@echo "🚀 Ejecutando ScreenCap..."
	@open $(APP_DIR)

# Ejecutar en modo debug
debug:
	@echo "🐛 Ejecutando en modo debug..."
	@swift run

# Crear DMG para distribución
dist: build
	@echo "📦 Creando imagen de disco para distribución..."
	@mkdir -p dist
	@rm -f dist/ScreenCap.dmg
	@rm -rf dist/temp
	@mkdir -p dist/temp
	@cp -R $(APP_DIR) dist/temp/
	@ln -s /Applications dist/temp/Applications
	@hdiutil create -volname "ScreenCap" -srcfolder dist/temp -ov -format UDBZ dist/ScreenCap.dmg
	@rm -rf dist/temp
	@echo "✅ DMG creado en dist/ScreenCap.dmg"
	@echo "📏 Tamaño del archivo: $$(du -h dist/ScreenCap.dmg | cut -f1)"

# Crear ZIP para distribución
zip: build
	@echo "🗜️ Creando archivo ZIP para distribución..."
	@mkdir -p dist
	@rm -f dist/ScreenCap.zip
	@cd $(BUILD_DIR) && zip -r ../dist/ScreenCap.zip $(APP_NAME).app
	@echo "✅ ZIP creado en dist/ScreenCap.zip"
	@echo "📏 Tamaño del archivo: $$(du -h dist/ScreenCap.zip | cut -f1)"

# Mostrar ayuda
help:
	@echo "Comandos disponibles:"
	@echo "  make build       - Compilar la aplicación"
	@echo "  make clean       - Limpiar archivos de compilación"
	@echo "  make install     - Instalar en /Applications (requiere sudo)"
	@echo "  make install-user - Instalar en ~/Applications (sin sudo)"
	@echo "  make run         - Ejecutar la aplicación"
	@echo "  make debug       - Ejecutar en modo debug"
	@echo "  make dist        - Crear DMG para distribución"
	@echo "  make zip         - Crear ZIP para distribución"
	@echo "  make help        - Mostrar esta ayuda"