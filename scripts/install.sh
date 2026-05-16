#!/usr/bin/env bash
# Installs Noto on Linux. Run from the repo root: sudo ./scripts/install.sh
set -euo pipefail
cd "$(dirname "$0")/.."

INSTALL_DIR="/usr/local/lib/noto"
BIN_LINK="/usr/local/bin/noto"
ICON_DIR="/usr/share/icons/hicolor/512x512/apps"
DESKTOP_DIR="/usr/share/applications"

if [[ $EUID -ne 0 ]]; then
  echo "Este script requiere permisos de administrador. Ejecútalo con sudo." >&2
  exit 1
fi

# 1. Verificar Flutter (buscar en PATH del usuario real si sudo no lo ve)
REAL_USER="${SUDO_USER:-$USER}"
FLUTTER_BIN=$(sudo -u "$REAL_USER" bash -lc 'command -v flutter 2>/dev/null || echo ""')
if [[ -z "$FLUTTER_BIN" ]]; then
  # Búsqueda de respaldo en ubicaciones comunes
  for candidate in \
    "/home/$REAL_USER/flutter/bin/flutter" \
    "/opt/flutter/bin/flutter" \
    "/usr/local/flutter/bin/flutter"; do
    if [[ -x "$candidate" ]]; then FLUTTER_BIN="$candidate"; break; fi
  done
fi
if [[ -z "$FLUTTER_BIN" ]]; then
  echo "Flutter no encontrado. Ajusta PATH o instala Flutter." >&2
  exit 1
fi
export FLUTTER="$FLUTTER_BIN"

# 2. Corregir linker si falta (necesario en algunos sistemas con LLVM)
LLVM_BIN=$(ls -d /usr/lib/llvm-*/bin 2>/dev/null | sort -V | tail -1)
if [[ -n "$LLVM_BIN" && ! -e "$LLVM_BIN/ld" ]]; then
  echo "Creando symlink de ld en $LLVM_BIN..."
  ln -s /usr/bin/ld "$LLVM_BIN/ld"
fi

# 3. Compilar
echo "Compilando Noto..."
sudo -u "$REAL_USER" "$FLUTTER" pub get
sudo -u "$REAL_USER" "$FLUTTER" build linux --release

# 4. Instalar el bundle
echo "Instalando en $INSTALL_DIR..."
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cp -r build/linux/x64/release/bundle/* "$INSTALL_DIR/"
chmod -R 755 "$INSTALL_DIR"

# 5. Symlink del binario
ln -sf "$INSTALL_DIR/noto" "$BIN_LINK"

# 6. Instalar icono
echo "Instalando icono..."
mkdir -p "$ICON_DIR"
cp assets/icon.png "$ICON_DIR/io.github.AngelAragonMartinez.Noto.png"
chmod 644 "$ICON_DIR/io.github.AngelAragonMartinez.Noto.png"
mkdir -p /usr/share/icons/hicolor/256x256/apps
cp assets/icon.png /usr/share/icons/hicolor/256x256/apps/io.github.AngelAragonMartinez.Noto.png
chmod 644 /usr/share/icons/hicolor/256x256/apps/io.github.AngelAragonMartinez.Noto.png
gtk-update-icon-cache /usr/share/icons/hicolor/ 2>/dev/null || true

# 7. Instalar .desktop
echo "Instalando entrada de aplicación..."
rm -f "$DESKTOP_DIR/noto.desktop"  # legacy name, anterior al fix de Wayland
cp linux/packaging/io.github.AngelAragonMartinez.Noto.desktop "$DESKTOP_DIR/io.github.AngelAragonMartinez.Noto.desktop"
chmod 644 "$DESKTOP_DIR/io.github.AngelAragonMartinez.Noto.desktop"
update-desktop-database "$DESKTOP_DIR/" 2>/dev/null || true

echo ""
echo "Noto instalado correctamente. Búscalo en el lanzador de aplicaciones."
