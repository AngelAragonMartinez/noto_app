# Noto

Notas locales para Linux con bóveda cifrada. Sin cuentas, sin sincronización en la nube.

**Local notes for Linux with an encrypted vault. No accounts, no cloud sync.**

---

## Características / Features

- **Cifrado AES-256-GCM** para la bóveda y los adjuntos — las claves viven en el llavero del sistema operativo.
- Editor de texto enriquecido (negrita, cursiva, listas, citas, bloques de código, imágenes en el cuerpo, etc.).
- Adjuntos cifrados por nota.
- Exportación a **PDF, RTF, Markdown, HTML, texto plano y JSON**.
- Importación desde archivos de texto, Markdown, HTML y JSON.
- Papelera con restauración y eliminación permanente.
- Temas claro y oscuro. Interfaz en español e inglés.
- Bloqueo biométrico opcional al abrir la app.

---

## Requisitos previos / Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install/linux) ≥ 3.4  
- Herramientas de compilación de Linux:

```bash
sudo apt install -y cmake ninja-build pkg-config libgtk-3-dev \
  libsecret-1-dev libjsoncpp-dev
```

> En otras distribuciones instala los paquetes equivalentes (`gtk3-devel`, `libsecret-devel`, etc.).

---

## Instalación desde el código fuente / Build from source

```bash
# 1. Clona el repositorio
git clone https://github.com/AngelAragonMartinez/noto_app.git
cd noto_app

# 2. Descarga las dependencias
flutter pub get

# 3. Ejecuta en modo debug
flutter run -d linux

# 4. O compila en modo release
flutter build linux --release
```

El binario queda en `build/linux/x64/release/bundle/`.

---

## Instalar en el sistema (entrada .desktop e ícono)

```bash
flutter build linux --release
cd build/linux/x64/release/bundle

# Instala el binario, el .desktop y los íconos en las rutas XDG estándar
cmake --install .
```

Después de esto aparece **Noto** en el lanzador de aplicaciones.

---

## Dónde se guardan los datos

La bóveda cifrada se almacena en:

```
~/.local/share/notes_app/vault.enc
~/.local/share/notes_app/attachments/
```

Los archivos exportados van por defecto a `~/.local/share/notes_app/exports/`.  
Los archivos que exportes a otras carpetas **no se borran** cuando eliminas una nota.

---

## Seguridad

La bóveda usa **AES-256-GCM**. Las claves se guardan en el llavero del sistema mediante `flutter_secure_storage` (Secret Service / libsecret en Linux). Los archivos exportados son texto plano — trátales como cualquier archivo sensible.

Si encuentras un problema de seguridad, abre un **security advisory privado** en GitHub en lugar de un issue público.

---

## Publicar una release en GitHub

```bash
chmod +x scripts/publish_github.sh
./scripts/publish_github.sh   # requiere `gh auth login`
```

---

## Licencia / License

MIT — ver [LICENSE](LICENSE).
