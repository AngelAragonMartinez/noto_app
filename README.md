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

## Instalación / Installation

### Requisitos previos / Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install/linux) ≥ 3.4
- Dependencias del sistema:

```bash
sudo apt install -y clang cmake ninja-build pkg-config libgtk-3-dev \
  libsecret-1-dev libjsoncpp-dev
```

> En otras distribuciones instala los paquetes equivalentes (`gtk3-devel`, `libsecret-devel`, etc.).

### Instalar con un solo comando / One-command install

```bash
git clone https://github.com/AngelAragonMartinez/noto_app.git
cd noto_app
sudo ./install.sh
```

Eso es todo. Noto aparece en el lanzador de aplicaciones como cualquier otra app instalada.  
No es necesario reiniciar. Si el ícono no aparece de inmediato, cierra y vuelve a abrir el lanzador.

> Si al escribir `noto` en la terminal aparece "command not found", añade `/usr/local/bin` a tu PATH:
> ```bash
> echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc
> ```

Para desinstalar: `sudo ./uninstall.sh`

---

## Compilar sin instalar / Build without installing

```bash
flutter pub get
flutter run -d linux          # modo debug
flutter build linux --release # binario en build/linux/x64/release/bundle/
```

---

## Dónde se guardan los datos

La bóveda cifrada se almacena en:

```
~/.local/share/notes_app/vault.enc
~/.local/share/notes_app/attachments/
```

Los archivos exportados van por defecto a `~/.local/share/notes_app/exports/`.  
Al desinstalar Noto, tus notas **no se borran**.

---

## Seguridad

La bóveda usa **AES-256-GCM**. Las claves se guardan en el llavero del sistema mediante `flutter_secure_storage`. Los archivos exportados son texto plano — trátales como cualquier archivo sensible.

Si encuentras un problema de seguridad, abre un **security advisory privado** en GitHub en lugar de un issue público.

---

## Licencia / License

MIT — ver [LICENSE](LICENSE).
