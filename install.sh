#!/usr/bin/env bash
# Noto — install script
# Usage: chmod +x install.sh && ./install.sh
set -euo pipefail

BINARY_NAME="noto"
APP_ID="com.example.notes_app"
BUNDLE_DIR="build/linux/x64/release/bundle"
INSTALL_DIR="/opt/$BINARY_NAME"
INSTALL_BIN="/usr/local/bin/$BINARY_NAME"
INSTALL_ICON="/usr/share/icons/hicolor/512x512/apps/$APP_ID.png"
INSTALL_DESKTOP="/usr/share/applications/$BINARY_NAME.desktop"

red()   { echo -e "\033[0;31m$*\033[0m"; }
green() { echo -e "\033[0;32m$*\033[0m"; }
info()  { echo -e "\033[0;34m:: $*\033[0m"; }

require() {
  command -v "$1" &>/dev/null || { red "Error: '$1' no encontrado. Instálalo y vuelve a intentarlo."; exit 1; }
}

# ── dependencias del sistema ──────────────────────────────────────────────────
info "Instalando dependencias del sistema (se pedirá contraseña)..."
sudo apt install -y clang cmake ninja-build pkg-config libgtk-3-dev \
  libsecret-1-dev libjsoncpp-dev

# ── checks ────────────────────────────────────────────────────────────────────
info "Verificando requisitos..."
require flutter

# ── build (como usuario normal) ───────────────────────────────────────────────
info "Descargando dependencias de Flutter..."
flutter pub get

# Parche: quill_native_bridge_windows 0.0.2 usa GMEM_MOVEABLE que fue removida en win32 5.x
QNBW="$HOME/.pub-cache/hosted/pub.dev/quill_native_bridge_windows-0.0.2/lib/quill_native_bridge_windows.dart"
if [ -f "$QNBW" ]; then
  sed -i 's/GlobalAlloc(GMEM_MOVEABLE,/GlobalAlloc(0x0002,/' "$QNBW"
fi

info "Compilando Noto en modo release (esto puede tardar unos minutos)..."
flutter build linux --release

# ── instalar al sistema (requiere sudo) ───────────────────────────────────────
info "Instalando en el sistema (se pedirá contraseña de administrador)..."

sudo bash -c "
  set -e

  # Copia el bundle completo a /opt/noto
  rm -rf '$INSTALL_DIR'
  cp -r '$BUNDLE_DIR/.' '$INSTALL_DIR/'
  chmod +x '$INSTALL_DIR/$BINARY_NAME'

  # Enlace simbólico para lanzarlo desde cualquier terminal
  ln -sf '$INSTALL_DIR/$BINARY_NAME' '$INSTALL_BIN'

  # Ícono
  mkdir -p '$(dirname $INSTALL_ICON)'
  cp 'assets/icon.png' '$INSTALL_ICON'

  # Entrada .desktop
  mkdir -p '$(dirname $INSTALL_DESKTOP)'
  cp 'linux/packaging/noto.desktop' '$INSTALL_DESKTOP'
  sed -i 's|^Exec=.*|Exec=$INSTALL_BIN|' '$INSTALL_DESKTOP'
  sed -i 's|^Icon=.*|Icon=$APP_ID|' '$INSTALL_DESKTOP'

  # Actualizar cachés
  gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true
  update-desktop-database '$(dirname $INSTALL_DESKTOP)' 2>/dev/null || true
"

green ""
green "✓ Noto instalado correctamente."
green "  Búscalo en el lanzador de aplicaciones o ejecuta: noto"
