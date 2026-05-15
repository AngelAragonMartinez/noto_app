#!/usr/bin/env bash
# Noto — install script
# Usage: chmod +x install.sh && ./install.sh
set -euo pipefail

BINARY_NAME="noto"
APP_ID="com.example.notes_app"
BUNDLE_DIR="build/linux/x64/release/bundle"
INSTALL_BIN="/usr/local/bin"
INSTALL_ICON="/usr/share/icons/hicolor/512x512/apps"
INSTALL_DESKTOP="/usr/share/applications"

# ── helpers ──────────────────────────────────────────────────────────────────
red()   { echo -e "\033[0;31m$*\033[0m"; }
green() { echo -e "\033[0;32m$*\033[0m"; }
info()  { echo -e "\033[0;34m:: $*\033[0m"; }

require() {
  command -v "$1" &>/dev/null || { red "Error: '$1' no encontrado. Instálalo y vuelve a intentarlo."; exit 1; }
}

# ── checks ────────────────────────────────────────────────────────────────────
info "Verificando requisitos..."
require flutter
require cmake

if [[ $EUID -ne 0 ]]; then
  red "Este script necesita permisos de administrador."
  info "Vuelve a ejecutarlo con: sudo ./install.sh"
  exit 1
fi

# ── build ─────────────────────────────────────────────────────────────────────
info "Descargando dependencias..."
flutter pub get

info "Compilando Noto (modo release)..."
flutter build linux --release

# ── install ───────────────────────────────────────────────────────────────────
info "Instalando binario en $INSTALL_BIN/$BINARY_NAME..."
install -Dm755 "$BUNDLE_DIR/$BINARY_NAME" "$INSTALL_BIN/$BINARY_NAME"

# Copia todas las librerías y datos del bundle junto al binario
NOTO_DATA_DIR="/usr/lib/$BINARY_NAME"
info "Copiando librerías en $NOTO_DATA_DIR..."
rm -rf "$NOTO_DATA_DIR"
cp -r "$BUNDLE_DIR/." "$NOTO_DATA_DIR/"
# El binario ya está en /usr/local/bin; el del bundle no hace falta ahí
rm -f "$NOTO_DATA_DIR/$BINARY_NAME"

# Actualiza el Exec= del .desktop para apuntar al binario instalado
sed -i "s|^Exec=.*|Exec=$INSTALL_BIN/$BINARY_NAME|" linux/packaging/noto.desktop

info "Instalando ícono..."
install -Dm644 assets/icon.png "$INSTALL_ICON/$APP_ID.png"

info "Instalando entrada de escritorio..."
install -Dm644 linux/packaging/noto.desktop "$INSTALL_DESKTOP/$BINARY_NAME.desktop"

info "Actualizando cachés..."
gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true
update-desktop-database "$INSTALL_DESKTOP" 2>/dev/null || true

green ""
green "✓ Noto instalado correctamente."
green "  Búscalo en el lanzador de aplicaciones o ejecuta: noto"
