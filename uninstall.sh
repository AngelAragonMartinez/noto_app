#!/usr/bin/env bash
# Noto — uninstall script
# Usage: chmod +x uninstall.sh && sudo ./uninstall.sh
set -euo pipefail

BINARY_NAME="noto"
APP_ID="io.github.AngelAragonMartinez.Noto"

red()   { echo -e "\033[0;31m$*\033[0m"; }
green() { echo -e "\033[0;32m$*\033[0m"; }
info()  { echo -e "\033[0;34m:: $*\033[0m"; }

if [[ $EUID -ne 0 ]]; then
  red "Este script necesita permisos de administrador."
  info "Vuelve a ejecutarlo con: sudo ./uninstall.sh"
  exit 1
fi

info "Eliminando Noto..."

rm -f  "/usr/bin/$BINARY_NAME"
rm -f  "/usr/local/bin/$BINARY_NAME"
rm -rf "/opt/$BINARY_NAME"
rm -f  "/usr/share/applications/$BINARY_NAME.desktop"
rm -f  "/usr/share/icons/hicolor/512x512/apps/$APP_ID.png"
rm -f  "/usr/share/icons/hicolor/256x256/apps/$APP_ID.png"

gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true
update-desktop-database /usr/share/applications 2>/dev/null || true

green "✓ Noto desinstalado."
green "  Tus notas en ~/.local/share/notes_app/ no se han borrado."
