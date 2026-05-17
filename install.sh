#!/usr/bin/env bash
# Noto — install script
# Usage: chmod +x install.sh && sudo ./install.sh
set -euo pipefail
cd "$(dirname "$0")"

BINARY_NAME="noto"
APP_ID="io.github.AngelAragonMartinez.Noto"
BUNDLE_DIR="build/linux/x64/release/bundle"
INSTALL_DIR="/opt/$BINARY_NAME"
INSTALL_BIN="/usr/bin/$BINARY_NAME"
INSTALL_ICON="/usr/share/icons/hicolor/512x512/apps/$APP_ID.png"
INSTALL_DESKTOP="/usr/share/applications/$APP_ID.desktop"

red()   { echo -e "\033[0;31m$*\033[0m"; }
green() { echo -e "\033[0;32m$*\033[0m"; }
info()  { echo -e "\033[0;34m:: $*\033[0m"; }

# ── permisos ──────────────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
  red "Este script necesita permisos de administrador."
  info "Vuelve a ejecutarlo con: sudo ./install.sh"
  exit 1
fi

# ── detectar distro ───────────────────────────────────────────────────────────
DISTRO_FAMILY=""
if [[ -r /etc/os-release ]]; then
  . /etc/os-release
  case "${ID:-}" in
    debian|ubuntu|linuxmint|pop|elementary)
      DISTRO_FAMILY="debian" ;;
    fedora|rhel|centos|rocky|alma|nobara)
      DISTRO_FAMILY="fedora" ;;
    *)
      case "${ID_LIKE:-}" in
        *debian*|*ubuntu*) DISTRO_FAMILY="debian" ;;
        *fedora*|*rhel*)   DISTRO_FAMILY="fedora" ;;
      esac
      ;;
  esac
fi

# Usuario real que ejecutó sudo (para correr Flutter sin root)
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

# ── buscar flutter ────────────────────────────────────────────────────────────
info "Buscando Flutter..."
FLUTTER_BIN=$(sudo -u "$REAL_USER" bash -lc 'command -v flutter 2>/dev/null || true')
if [[ -z "$FLUTTER_BIN" ]]; then
  for candidate in \
    "$REAL_HOME/flutter/bin/flutter" \
    "$REAL_HOME/development/flutter/bin/flutter" \
    "/opt/flutter/bin/flutter" \
    "/usr/local/flutter/bin/flutter"; do
    if [[ -x "$candidate" ]]; then FLUTTER_BIN="$candidate"; break; fi
  done
fi
if [[ -z "$FLUTTER_BIN" ]]; then
  red "Error: Flutter no encontrado. Instálalo y asegúrate de que esté en el PATH de '$REAL_USER'."
  exit 1
fi
info "Flutter encontrado: $FLUTTER_BIN"

# ── dependencias del sistema ──────────────────────────────────────────────────
info "Instalando dependencias del sistema..."
case "$DISTRO_FAMILY" in
  debian)
    apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev \
      libsecret-1-dev libjsoncpp-dev
    ;;
  fedora)
    dnf install -y clang cmake ninja-build pkgconf-pkg-config gtk3-devel \
      libsecret-devel jsoncpp-devel
    ;;
  *)
    red "Distribución no reconocida en /etc/os-release."
    info "Instala manualmente: clang, cmake, ninja, pkg-config, gtk3-devel, libsecret-devel, jsoncpp-devel."
    exit 1
    ;;
esac

# ── build como usuario normal ─────────────────────────────────────────────────
info "Descargando dependencias de Flutter..."
sudo -u "$REAL_USER" "$FLUTTER_BIN" pub get

# Parche: quill_native_bridge_windows 0.0.2 usa GMEM_MOVEABLE removida en win32 5.x
QNBW="$REAL_HOME/.pub-cache/hosted/pub.dev/quill_native_bridge_windows-0.0.2/lib/quill_native_bridge_windows.dart"
if [ -f "$QNBW" ]; then
  sed -i 's/GlobalAlloc(GMEM_MOVEABLE,/GlobalAlloc(0x0002,/' "$QNBW"
fi

info "Compilando Noto en modo release (esto puede tardar unos minutos)..."
sudo -u "$REAL_USER" "$FLUTTER_BIN" build linux --release

# ── instalar en el sistema ────────────────────────────────────────────────────
info "Instalando en el sistema..."

rm -rf "$INSTALL_DIR"
cp -r "$BUNDLE_DIR/." "$INSTALL_DIR/"
chmod -R 755 "$INSTALL_DIR"

ln -sf "$INSTALL_DIR/$BINARY_NAME" "$INSTALL_BIN"

mkdir -p "$(dirname "$INSTALL_ICON")"
cp assets/icon.png "$INSTALL_ICON"
chmod 644 "$INSTALL_ICON"

# Also install a 256×256 copy for icon themes that look there first
INSTALL_ICON_256="/usr/share/icons/hicolor/256x256/apps/$APP_ID.png"
mkdir -p "$(dirname "$INSTALL_ICON_256")"
cp assets/icon.png "$INSTALL_ICON_256"
chmod 644 "$INSTALL_ICON_256"

mkdir -p "$(dirname "$INSTALL_DESKTOP")"
# Quitar entrada con nombre legacy si existe (anterior al fix de matching en Wayland)
rm -f "/usr/share/applications/$BINARY_NAME.desktop"
cp linux/packaging/io.github.AngelAragonMartinez.Noto.desktop "$INSTALL_DESKTOP"
sed -i "s|^Exec=.*|Exec=$INSTALL_BIN|" "$INSTALL_DESKTOP"
chmod 644 "$INSTALL_DESKTOP"

gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true
update-desktop-database "$(dirname "$INSTALL_DESKTOP")" 2>/dev/null || true

green ""
green "✓ Noto instalado correctamente."
green "  Búscalo en el lanzador de aplicaciones o ejecuta: noto"
