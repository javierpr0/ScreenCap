#!/bin/bash

# Script de distribución para ScreenCap
# Este script crea una versión completamente independiente de la aplicación

echo "🚀 Iniciando proceso de distribución para ScreenCap..."

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Verificar que estamos en el directorio correcto
if [ ! -f "Package.swift" ]; then
    echo -e "${RED}Error: Este script debe ejecutarse desde el directorio raíz del proyecto${NC}"
    exit 1
fi

# Limpiar compilaciones anteriores
echo "🧹 Limpiando compilaciones anteriores..."
make clean

# Compilar en modo release con optimizaciones
echo "🔨 Compilando aplicación en modo release..."
swift build -c release -Xswiftc -O

# Crear el bundle de la aplicación
echo "📦 Creando bundle de aplicación..."
make build

# Verificar que la aplicación se compiló correctamente
if [ ! -d ".build/ScreenCap.app" ]; then
    echo -e "${RED}Error: La aplicación no se compiló correctamente${NC}"
    exit 1
fi

# Crear directorio de distribución
echo "📁 Preparando directorio de distribución..."
rm -rf dist
mkdir -p dist

# Opción 1: Crear DMG
echo "💿 Creando imagen de disco (DMG)..."
mkdir -p dist/dmg-temp
cp -R .build/ScreenCap.app dist/dmg-temp/
ln -s /Applications dist/dmg-temp/Applications

# Crear README para el DMG
cat > dist/dmg-temp/README.txt << EOF
ScreenCap - Herramienta de captura de pantalla para macOS

INSTALACIÓN:
1. Arrastra ScreenCap.app a la carpeta Applications
2. La primera vez que ejecutes la aplicación, macOS te pedirá permisos
3. Ve a Preferencias del Sistema > Seguridad y Privacidad > Privacidad > Grabación de pantalla
4. Marca la casilla junto a ScreenCap

USO:
- La aplicación se ejecuta en la barra de menú (arriba a la derecha)
- Haz clic en el icono de la cámara para ver las opciones
- Atajos de teclado:
  • ⌘⇧1: Captura pantalla completa
  • ⌘⇧2: Captura de selección
  • ⌘⇧3: Captura de ventana

¡Disfruta usando ScreenCap!
EOF

# Crear el DMG
hdiutil create -volname "ScreenCap" -srcfolder dist/dmg-temp -ov -format UDBZ dist/ScreenCap.dmg
rm -rf dist/dmg-temp

# Opción 2: Crear ZIP
echo "🗜️ Creando archivo ZIP..."
cd .build
zip -r ../dist/ScreenCap.zip ScreenCap.app -x "*.DS_Store"
cd ..

# Crear archivo de instrucciones
cat > dist/INSTRUCCIONES.txt << EOF
INSTRUCCIONES DE INSTALACIÓN - ScreenCap

=== IMPORTANTE ===
La primera vez que ejecutes ScreenCap, macOS mostrará advertencias de seguridad.
Esto es normal para aplicaciones descargadas de Internet.

=== PASOS DE INSTALACIÓN ===

1. DESCOMPRIMIR (si descargaste el ZIP):
   - Haz doble clic en ScreenCap.zip
   - Se creará ScreenCap.app

2. INSTALAR:
   - Arrastra ScreenCap.app a tu carpeta Aplicaciones

3. PRIMERA EJECUCIÓN:
   - Haz clic derecho en ScreenCap.app
   - Selecciona "Abrir"
   - Aparecerá una advertencia de seguridad
   - Haz clic en "Abrir" nuevamente

4. PERMISOS NECESARIOS:
   - Ve a: Preferencias del Sistema > Seguridad y Privacidad
   - Selecciona la pestaña "Privacidad"
   - En la lista izquierda, selecciona "Grabación de pantalla"
   - Marca la casilla junto a ScreenCap
   - Es posible que necesites reiniciar la aplicación

=== SOLUCIÓN DE PROBLEMAS ===

Si macOS dice "ScreenCap está dañado":
1. Abre Terminal
2. Ejecuta: xattr -cr /Applications/ScreenCap.app
3. Intenta abrir la aplicación nuevamente

Si los atajos de teclado no funcionan:
1. Ve a: Preferencias del Sistema > Seguridad y Privacidad > Privacidad > Accesibilidad
2. Añade ScreenCap a la lista y marca la casilla

=== DESINSTALACIÓN ===
1. Arrastra ScreenCap.app desde Aplicaciones a la Papelera
2. Vacía la Papelera

Disfruta usando ScreenCap!
EOF

# Mostrar información del build
echo ""
echo -e "${GREEN}✅ Distribución completada exitosamente!${NC}"
echo ""
echo "📦 Archivos creados:"
echo "  - dist/ScreenCap.dmg ($(du -h dist/ScreenCap.dmg | cut -f1))"
echo "  - dist/ScreenCap.zip ($(du -h dist/ScreenCap.zip | cut -f1))"
echo "  - dist/INSTRUCCIONES.txt"
echo ""
echo -e "${YELLOW}📋 Información de la compilación:${NC}"
echo "  - Arquitectura: $(uname -m)"
echo "  - macOS versión mínima: 14.0"
echo "  - Swift version: $(swift --version | head -n 1)"
echo ""
echo -e "${YELLOW}🔐 Firma de código:${NC}"
echo "  - La aplicación está firmada localmente (ad-hoc)"
echo "  - Los usuarios verán advertencias de seguridad en la primera ejecución"
echo "  - Para distribución sin advertencias, necesitas:"
echo "    • Una cuenta de desarrollador de Apple (\$99/año)"
echo "    • Firmar con un certificado válido"
echo "    • Notarizar la aplicación con Apple"
echo ""
echo "📨 Los archivos están listos para compartir en la carpeta 'dist/'"