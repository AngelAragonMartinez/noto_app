# Noto

Local encrypted notes for Linux. No accounts, no sync, no cloud.

<br>

<p align="center">
  <img src="screenshots/welcome.png" width="640" alt="Welcome screen"/>
</p>

<p align="center">
  <img src="screenshots/editor.png" width="640" alt="Note editor"/>
</p>

<br>

---

## Features

- Encrypts your vault with **AES-256-GCM** — keys live in the OS keyring, never on disk in plaintext
- Rich text editor: bold, italic, lists, code blocks, and inline images
- Encrypted per-note attachments
- Export to **PDF, RTF, Markdown, HTML, plain text,** and **JSON**
- Import from text, Markdown, HTML, and JSON
- Trash with restore and permanent delete
- Light and dark themes · English and Spanish
- Optional biometric lock on startup

---

## Install

Requires **Flutter SDK ≥ 3.4** on a Debian/Ubuntu system.

```bash
git clone https://github.com/AngelAragonMartinez/noto_app.git
cd noto_app
sudo ./install.sh
```

The script installs system dependencies, builds Noto, and registers it in your app launcher.

```bash
sudo ./uninstall.sh   # to remove
```

> On other distributions, install the GTK 3, libsecret, and jsoncpp development packages before running the script.

---

## Build without installing

```bash
flutter pub get
flutter run -d linux           # debug
flutter build linux --release  # release build → build/linux/x64/release/bundle/
```

---

## Your data

Notes live at `~/.local/share/notes_app/`. Uninstalling Noto leaves this folder untouched.

Exported files are plaintext — handle them like any sensitive document.

---

## Security

To report a vulnerability, open a [private security advisory](https://github.com/AngelAragonMartinez/noto_app/security/advisories/new) on GitHub rather than a public issue.

---

## License

[MIT](LICENSE)
