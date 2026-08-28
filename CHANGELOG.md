# Changelog

## 1.0.0

First release with installable builds. Before this, running Noto on Windows
meant cloning the repository, installing the Flutter SDK and Visual Studio, and
compiling it yourself — and that build did not actually work.

### Installing

- **Windows installer.** A signed-in-as-you, no-UAC `.exe` that registers in
  Settings ▸ Apps and leaves your notes alone when uninstalled. A portable
  `.zip` is published alongside it.
- **Linux tarball**, built against glibc 2.35 so it runs on Debian 12+ and
  Ubuntu 22.04+. CI fails the build if anything in the bundle raises that
  requirement.
- Every release ships SHA-256 checksums.

### Fixed: the Windows build

Four separate problems, each hidden behind the one before it:

- `install.ps1` never applied the dependency patches that `install.sh` did, so
  `quill_native_bridge_windows` failed against win32 5's removed
  `GMEM_MOVEABLE`. Both installers and CI now share one patch script.
- `local_auth` was capped below 3.0, holding a plugin two major versions back.
- That plugin compiled with `/await`, MSVC's pre-standard coroutine switch,
  which forces a header current toolsets reject outright.
- Removing `/await` exposed a `return` inside a coroutine, which standard C++20
  does not allow.

The app icon is now the real Noto icon; released builds previously carried
Flutter's default logo.

### Security

- **Images embedded in note bodies are now encrypted.** They were written to
  disk as raw bytes while attachments were encrypted — the one content path
  that escaped the vault. Existing images keep working and are re-encrypted as
  their notes are opened.
- **Fixed command injection when opening an attachment on Windows.** The file
  name reached `cmd` unescaped, so an attachment named `invoice&calc&.pdf` ran
  `calc`. Attachments now open without a shell in the chain, and file names go
  through an allowlist.
- **Decrypted attachment copies are cleaned up.** They accumulated in the temp
  directory permanently; they are now removed on exit, and any a crash left
  behind are swept on next launch.
- **Permanent delete works on Windows.** A case-sensitive path comparison meant
  inline images and export copies were silently left on disk.
- **The startup lock fails closed.** It previously unlocked whenever the
  biometric check errored, and a missing `await` meant the error escaped and
  hung the app on its loading spinner.

### Dependencies and tooling

- Nine dependencies were declared `any`. All constraints are pinned now — that
  looseness is what let an SDK update break the Windows build in the first
  place.
- Upgraded `flutter_secure_storage` to 11, `go_router` to 18, `local_auth` to 3,
  and five others.
- Continuous integration: analysis, tests, and release builds for Windows and
  Linux on every pull request. Actions are pinned to commit SHAs and the
  workflow token is read-only.

### Also

- Importing HTML produced a note full of literal `<p>` tags; it now imports as
  readable text.
- The documented data paths were wrong on both platforms.
- Corrected the README's encryption claims, which promised more than the code
  delivered.
