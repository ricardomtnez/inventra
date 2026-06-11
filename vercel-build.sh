#!/bin/bash
# Script de construcción para desplegar Flutter Web en Vercel
set -e

echo "=== 🚀 INICIANDO INSTALACIÓN DE FLUTTER SDK EN /tmp ==="
if [ ! -d "/tmp/flutter" ]; then
  echo "Clonando Flutter SDK (rama stable)..."
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 /tmp/flutter
else
  echo "Flutter SDK detectado en /tmp/flutter. Actualizando repositorio..."
  cd /tmp/flutter && git pull && cd -
fi

# Exportar el binario de Flutter al PATH
export PATH="$PATH:/tmp/flutter/bin"

echo "=== ⚙️ CONFIGURANDO ENTORNO FLUTTER ==="
flutter config --no-analytics
flutter config --enable-web

echo "=== 🔍 DETALLES DEL SDK ==="
flutter --version

echo "=== 📦 INSTALANDO DEPENDENCIAS DE PUBSPEC ==="
flutter pub get

echo "=== 🛠️ COMPILANDO FLUTTER WEB (RELEASE) ==="
flutter build web --release

echo "=== 🎉 PROCESO DE CONSTRUCCIÓN COMPLETADO EXITOSAMENTE ==="
