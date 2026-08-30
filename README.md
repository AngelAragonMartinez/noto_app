<h1 align="center">Noto</h1>

<p align="center">
  <strong>Local encrypted notes for Windows and Linux.</strong><br>
  No accounts. No sync. No cloud. Nothing leaves your machine.
</p>

<p align="center">
  <a href="https://github.com/AngelAragonMartinez/noto_app/releases/latest">
    <img src="https://img.shields.io/github/v/release/AngelAragonMartinez/noto_app?label=download&style=for-the-badge" alt="Latest release"/>
  </a>
  <img src="https://img.shields.io/badge/license-MIT-blue?style=for-the-badge" alt="MIT"/>
  <img src="https://img.shields.io/badge/encryption-AES--256--GCM-brightgreen?style=for-the-badge" alt="AES-256-GCM"/>
</p>

<br>

<p align="center">
  <img src="screenshots/welcome.png" width="640" alt="Welcome screen"/>
</p>

<p align="center">
  <img src="screenshots/editor.png" width="640" alt="Note editor"/>
</p>

<br>

---

## Install on Windows

**[⬇ Download the installer](https://github.com/AngelAragonMartinez/noto_app/releases/latest)** — the file ending in **`-windows-x64-setup.exe`**

Double-click it. That's the whole process.

> The file name carries the version — `Noto-1.1.0-windows-x64-setup.exe`, for
> example. Commands below use `Noto-*` so they work whichever version you
> downloaded.

- **No admin rights needed.** Noto installs for your user only, so Windows
  never shows a UAC prompt.
- **No developer tools.** You do not need Flutter, Visual Studio, or a terminal.
- **Uninstalls normally**, from Settings ▸ Apps. Your notes are left untouched.

<details>
<summary><strong>Windows says "unknown publisher" — is that normal?</strong></summary>

<br>

Yes. The installer is not code-signed, because a signing certificate is a paid
yearly subscription. SmartScreen warns about any unsigned installer regardless
of what it contains.

Click **More info ▸ Run anyway**, or verify the download first.

Download `SHA256SUMS-windows.txt` alongside the installer, then run this from
the folder holding both. It prints a verdict rather than leaving you to compare
64 characters by eye:

```powershell
$e = (Get-FileHash .\Noto-*-windows-x64-setup.exe -Algorithm SHA256).Hash.ToLower(); $p = ((Select-String .\SHA256SUMS-windows.txt -Pattern 'setup\.exe').Line -split '\s+')[0]; if ($e -eq $p) { "MATCH - safe to run" } else { "MISMATCH - do not run" }
```

A match means the file is byte-for-byte what CI built from this repository.

Both files come from the same release page, so for the strongest check compare
against the checksum printed in the build log itself: open the run for your
version under [Actions](https://github.com/AngelAragonMartinez/noto_app/actions),
job **Windows installer**, step **Checksums**. That line was written by GitHub's
machine, not by the release.
</details>

<details>
<summary><strong>I'd rather not install anything</strong></summary>

<br>

Grab the `-windows-x64-portable.zip` file from the same release, unzip it
anywhere, and run `noto.exe`. Nothing is written outside the folder you chose
and your notes directory.
</details>

---

## Install on Linux

**[⬇ Download the tarball](https://github.com/AngelAragonMartinez/noto_app/releases/latest)** — the file ending in **`-linux-x64.tar.gz`**

```bash
mkdir -p ~/noto && tar -xzf Noto-*-linux-x64.tar.gz -C ~/noto
~/noto/noto
```

Prebuilt binaries need **glibc 2.36 or newer** — Debian 12+, Ubuntu 22.04+,
Fedora 37+.

<details>
<summary><strong>Build from source instead</strong> (older distros, or to register Noto in your app launcher)</summary>

<br>

Requires **Flutter SDK ≥ 3.44**:

```bash
git clone https://github.com/AngelAragonMartinez/noto_app.git
cd noto_app
sudo ./install.sh
```

The script installs system dependencies, builds Noto, and adds it to your
application menu.

```bash
sudo ./uninstall.sh   # to remove
```

On distributions other than Debian/Ubuntu and Fedora, install the GTK 3,
libsecret, and jsoncpp development packages first.
</details>

---

## What it does

- **Rich text editor** — bold, italic, lists, quotes, code blocks, alignment,
  links, find and replace, and images placed inline in the text
- **Export** to PDF, RTF, Markdown, HTML, plain text, and JSON
- **Import** from text, Markdown, HTML, and JSON — JSON round-trips formatting;
  the others come in as text
- **Attachments** stored inside the vault, opened with your default app
- **Trash** with restore and permanent delete
- **Light and dark themes**, English and Spanish
- **Optional lock on startup**, using Windows Hello or your device credential — toggle it from the lock button in the top bar

---

## How your notes are protected

Everything Noto stores on disk is encrypted with **AES-256-GCM**: the vault
itself, per-note attachments, and images embedded in note bodies. A fresh
random nonce is generated for every single write.

The encryption keys are generated from a cryptographically secure random
source and kept in your operating system's keyring — Credential Manager on
Windows, libsecret on Linux. **They are never written to disk in plaintext.**

Noto makes **no network requests of any kind**. There is no telemetry, no
analytics, no update check, and no account. The application has never had a
line of networking code in it.

### Where everything lives

Noto uses two locations, and they are deliberately separate: **uninstalling
removes the first and never touches the second.**

**The application**

| Platform | Location |
|---|---|
| Windows (installer) | `%LOCALAPPDATA%\Programs\Noto\` |
| Windows (portable) | wherever you unzipped it |
| Linux (`install.sh`) | `/opt/noto/`, launched via `/usr/bin/noto` |
| Linux (tarball) | wherever you unpacked it |

**Your notes**

| Platform | Location |
|---|---|
| Windows | `%APPDATA%\Noto contributors\Noto\notes_app\` |
| Linux | `~/.local/share/noto/notes_app/` |

Inside that folder:

| Item | What it holds |
|---|---|
| `vault.enc` | every note — encrypted |
| `attachments/` | files attached to notes — encrypted |
| `inline_images/` | images placed in note bodies — encrypted |
| `exports/` | the default folder the Save-as dialog opens in — **plaintext** |
| `locale`, `app_lock` | your language and startup-lock preferences |

Back this folder up like any other irreplaceable data. There is no cloud copy,
by design.

### Uninstalling

**Windows** — Settings ▸ Apps ▸ Installed apps ▸ Noto ▸ Uninstall.

If it is not listed there, run the uninstaller directly. Paste this into File
Explorer:

```
%LOCALAPPDATA%\Programs\Noto
```

and run **`unins000.exe`**. Installed from the portable `.zip` instead? There is
nothing to uninstall — delete the folder you unzipped.

**Linux** — `sudo ./uninstall.sh` from the repository, or delete the folder you
unpacked the tarball into.

Either way your notes survive. To remove those too, delete the notes folder
above by hand — that step is irreversible.

### What is *not* protected

Two things worth knowing, stated plainly rather than buried:

- **Exported files are plaintext.** A PDF or Markdown file you save is a normal
  document. Handle it accordingly.
- **Opening an attachment** writes a decrypted copy to your temp directory, so
  the operating system can hand it to the right application. Noto deletes those
  copies when it closes, and clears any a crash left behind on next launch —
  but while an attachment is open, a plaintext copy exists.

Full details in [SECURITY.md](SECURITY.md).

---

## Development

```bash
flutter pub get
dart run tool/patch_pub_cache.dart   # see the script for what and why
flutter run -d windows               # or: -d linux
```

```bash
flutter analyze
flutter test
```

Every pull request runs analysis, tests, and release builds for both platforms.
Releases are cut by pushing a `v*` tag, which builds and publishes the
installer, the portable archive, the Linux tarball, and their checksums.

---

## License

[MIT](LICENSE) — see [CHANGELOG.md](CHANGELOG.md) for what changed between
versions.
