#!/bin/bash

# Script para generar iconset desde icon.png
set -e  # Detener ejecución si algún comando falla

# Verificar si el archivo de entrada existe
if [ ! -f "icon.png" ]; then
    echo "❌ Error: No se encontró el archivo icon.png"
    exit 1
fi

# Verificar permisos de escritura en el directorio actual
if [ ! -w "$(pwd)" ]; then
    echo "❌ Error: No tienes permisos de escritura en el directorio actual"
    exit 1
fi

echo "🎨 Generando conjunto de iconos para ScreenCap..."

# Crear directorio temporal para el iconset
mkdir -p ScreenCap.iconset || { echo "❌ Error: No se pudo crear el directorio ScreenCap.iconset"; exit 1; }

# Generar todos los tamaños necesarios
sips -z 16 16     icon.png --out ScreenCap.iconset/icon_16x16.png || { echo "❌ Error al generar icono 16x16"; exit 1; }
sips -z 32 32     icon.png --out ScreenCap.iconset/icon_16x16@2x.png || { echo "❌ Error al generar icono 16x16@2x"; exit 1; }
sips -z 32 32     icon.png --out ScreenCap.iconset/icon_32x32.png || { echo "❌ Error al generar icono 32x32"; exit 1; }
sips -z 64 64     icon.png --out ScreenCap.iconset/icon_32x32@2x.png || { echo "❌ Error al generar icono 32x32@2x"; exit 1; }
sips -z 128 128   icon.png --out ScreenCap.iconset/icon_128x128.png || { echo "❌ Error al generar icono 128x128"; exit 1; }
sips -z 256 256   icon.png --out ScreenCap.iconset/icon_128x128@2x.png || { echo "❌ Error al generar icono 128x128@2x"; exit 1; }
sips -z 256 256   icon.png --out ScreenCap.iconset/icon_256x256.png || { echo "❌ Error al generar icono 256x256"; exit 1; }
sips -z 512 512   icon.png --out ScreenCap.iconset/icon_256x256@2x.png || { echo "❌ Error al generar icono 256x256@2x"; exit 1; }
sips -z 512 512   icon.png --out ScreenCap.iconset/icon_512x512.png || { echo "❌ Error al generar icono 512x512"; exit 1; }
sips -z 1024 1024 icon.png --out ScreenCap.iconset/icon_512x512@2x.png || { echo "❌ Error al generar icono 512x512@2x"; exit 1; }

# Verificar que iconutil está disponible
if ! command -v iconutil &> /dev/null; then
    echo "❌ Error: El comando iconutil no está disponible"
    exit 1
fi

# Generar archivo .icns
echo "Generando archivo .icns..."
iconutil -c icns ScreenCap.iconset || { 
    echo "❌ Error al generar archivo .icns"
    # Verificar si el archivo de salida existe a pesar del error
    if [ -f "ScreenCap.icns" ]; then
        echo "⚠️ El archivo ScreenCap.icns existe pero puede estar corrupto"
    fi
    exit 1
}

# Limpiar directorio temporal
if [ -d "ScreenCap.iconset" ]; then
    rm -rf ScreenCap.iconset || { 
        echo "⚠️ Advertencia: No se pudo eliminar el directorio temporal"
        # No es un error crítico, continuamos
    }
fi

echo "✅ Archivo ScreenCap.icns generado exitosamente"