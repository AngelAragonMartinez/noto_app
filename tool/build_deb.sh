#!/usr/bin/env bash
# Builds a .deb from an already-compiled Linux bundle.
#
# Linux only ever shipped a tarball: download, extract, run the binary by hand,
# no menu entry and no icon. Windows got an installer. This closes that gap with
# the format Debian and Ubuntu users expect.
#
# Usage: flutter build linux --release && tool/build_deb.sh
set -euo pipefail
cd "$(dirname "$0")/.."

APP_ID="io.github.AngelAragonMartinez.Noto"
BINARY_NAME="noto"
BUNDLE="build/linux/x64/release/bundle"
OUT_DIR="dist"

if [[ ! -x "$BUNDLE/$BINARY_NAME" ]]; then
  echo "No bundle at $BUNDLE. Run: flutter build linux --release" >&2
  exit 1
fi

# 1.1.4+6 -> 1.1.4. The build number is Flutter's, not Debian's.
VERSION=$(grep '^version:' pubspec.yaml | sed 's/^version:[[:space:]]*//' | cut -d+ -f1)
ARCH=$(dpkg --print-architecture)
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

echo ":: Staging $BINARY_NAME $VERSION ($ARCH)"
install -d "$STAGE/opt/$BINARY_NAME" "$STAGE/usr/bin" "$STAGE/DEBIAN"
cp -r "$BUNDLE/." "$STAGE/opt/$BINARY_NAME/"
ln -s "/opt/$BINARY_NAME/$BINARY_NAME" "$STAGE/usr/bin/$BINARY_NAME"

install -Dm644 "linux/packaging/$APP_ID.desktop" \
  "$STAGE/usr/share/applications/$APP_ID.desktop"
# The shipped entry points at /usr/local/bin, which is where install.sh used to
# put things. A packaged binary lives on PATH at /usr/bin.
sed -i "s|^Exec=.*|Exec=/usr/bin/$BINARY_NAME|" \
  "$STAGE/usr/share/applications/$APP_ID.desktop"

for size in 256 512; do
  install -Dm644 assets/icon.png \
    "$STAGE/usr/share/icons/hicolor/${size}x${size}/apps/$APP_ID.png"
done

# Dependencies are read off the binaries rather than listed by hand, so a new
# plugin cannot quietly ship a package that fails to start on someone's machine.
echo ":: Resolving dependencies"
DEPS_DIR=$(mktemp -d)
trap 'rm -rf "$STAGE" "$DEPS_DIR"' EXIT
mkdir -p "$DEPS_DIR/debian"
printf 'Source: %s\nPackage: %s\nArchitecture: %s\n' \
  "$BINARY_NAME" "$BINARY_NAME" "$ARCH" > "$DEPS_DIR/debian/control"
# $STAGE is already absolute; dpkg-shlibdeps only needs to run from a
# directory holding debian/control, so the paths stay as they are.
SHLIBS=$(cd "$DEPS_DIR" && dpkg-shlibdeps -O --ignore-missing-info \
  "$STAGE/opt/$BINARY_NAME/$BINARY_NAME" \
  "$STAGE/opt/$BINARY_NAME"/lib/*.so 2>/dev/null \
  | sed 's/^shlibs:Depends=//' || true)
DEPENDS="${SHLIBS:-libgtk-3-0, libsecret-1-0}"

cat > "$STAGE/DEBIAN/control" <<CONTROL
Package: $BINARY_NAME
Version: $VERSION
Section: utils
Priority: optional
Architecture: $ARCH
Depends: $DEPENDS
Maintainer: AngelAragonMartinez <180601544+AngelAragonMartinez@users.noreply.github.com>
Homepage: https://github.com/AngelAragonMartinez/noto_app
Description: Local, encrypted notes
 Noto keeps notes in an encrypted vault on your own device, with no account
 and no cloud. It exports to PDF, RTF, HTML, Markdown, plain text and JSON.
CONTROL

cat > "$STAGE/DEBIAN/postinst" <<'POSTINST'
#!/bin/sh
set -e
gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true
update-desktop-database /usr/share/applications 2>/dev/null || true
POSTINST
chmod 755 "$STAGE/DEBIAN/postinst"
cp "$STAGE/DEBIAN/postinst" "$STAGE/DEBIAN/postrm"

mkdir -p "$OUT_DIR"
DEB="$OUT_DIR/${BINARY_NAME}_${VERSION}_${ARCH}.deb"
dpkg-deb --build --root-owner-group "$STAGE" "$DEB" >/dev/null
( cd "$OUT_DIR" && sha256sum "$(basename "$DEB")" > SHA256SUMS-deb.txt )

echo ":: Built $DEB"
dpkg-deb --info "$DEB" | sed 's/^/   /'
