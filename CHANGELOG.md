# Changelog

## 1.1.4

### Tags come back when you reopen a note

Exporting to `.txt` or `.md` writes tags as a line of text, since neither
format has anywhere else to keep them. Reopening such a file left that line
sitting in the body while the tags field came back empty. Import now lifts it
back out.

Both labels are recognised in both languages Noto exports in, so a note saved
in Spanish reopens with its tags whatever language is active now. Only a line
of its own counts — a sentence that happens to begin "Tags:" stays in the body.

### A button showing where the note is

A folder button beside the lock and About buttons writes the note's location
into the same bar that confirms a save; pressing it again clears it.

It shows the file the note was last exported to when there is one, and
otherwise the folder holding the vault, since a note never exported has no file
of its own. The message stays until dismissed rather than timing out — a path
is there to be read and written down.

### PDFs no longer list attachments

Exports ended with a list naming each attachment and its path into a sibling
folder. A PDF is the format people forward on its own, so those paths point at
a folder the reader does not have. Plain text, Markdown and HTML keep the list,
since those are read next to the exported folder.

### More room to write when the side panel is hidden

Hiding the panel is a request for space, but the writing column stayed narrow,
reading as a strip adrift under a full-width toolbar. It now widens. Still
capped rather than filling the window: a line spanning a large monitor is
tiring to read.


## 1.1.3

### Fixed: copy and paste in the note body

Paste in the body did nothing — mouse or keyboard — while it worked in the
title field and Ctrl+Z worked everywhere. Undo working showed the editor had
focus and received input, placing the fault in the clipboard path alone.

flutter_quill tries the Windows native bridge first, for HTML and then
Markdown, before falling back to plain text. That bridge is the only
non-default piece in the path, and the title field, which uses Flutter's own
clipboard, never broke. Noto now skips the bridge, so the body pastes the same
way the title does.

**Content pasted from other applications arrives as plain text** rather than
keeping its formatting. Paste working at all is worth more.

### Noto starts in the language you chose

The installer asks for English or Spanish and the app ignored it, always
opening in English. The installer now seeds that choice, so the welcome screen
and the built-in guide note appear in the language you picked.

Without an installer — the portable archive, or Linux — Noto follows the
operating system instead, falling back to English for languages it has no
translation for. Changing the language inside Noto overrides both and survives
upgrades.


## 1.1.2

### Fixed: copying in the note body wiped the clipboard

Copy and paste worked in the title field but not in the note body. The title is
an ordinary text field; the body goes through `quill_native_bridge_windows`,
whose `copyHtmlToClipboard` calls `EmptyClipboard()` and then writes only HTML.
Flutter had already put the plain text there, so the wipe removed it and
nothing readable was left. Every failure in that code is reported with
`assert`, which release builds strip, so it happened silently.

Noto now uses Flutter's own clipboard for copying, which writes plain text and
empties nothing. Pasting formatted content into Noto still works.

**Copying out of Noto no longer carries formatting into other applications** —
it pastes as plain text. Copying working at all is worth more.

### Fixed: exported files could be saved unusable

The extension was appended only when the file name had none. A name containing
a dot — "Reunión 20.08", "nota v1.2" — looked like it already had one, so the
file was written without a usable extension and other devices reported it as
damaged. Choosing PDF with a name ending in `.txt` left the mismatch in place,
putting PDF bytes in a file everything reads as text.

Saved files now always end with the extension matching their contents.

### Fixed: colours and highlights vanished on export

RTF — the format Word opens — lost both, declaring a colour table containing
only black. PDF applied text colour but dropped highlighting. Markdown dropped
highlighting. All three now carry them.


## 1.1.1

### Fixed: the lock button did nothing on devices without Windows Hello

Where no Windows Hello credential exists the startup lock cannot engage. The
button rendered disabled with the reason hidden in a tooltip, so from the
outside it was indistinguishable from a broken control: it showed the lock
already off, and clicking did nothing at all.

It now stays pressable and explains itself — naming the cause, giving the path
to fix it in Windows Settings, and stating that notes are encrypted either way,
so an unavailable lock is not mistaken for unprotected notes.

### Documentation

The README and SECURITY.md now list every path Noto uses: where the app
installs on each of the four install routes, what each file inside the notes
folder holds and which of them are encrypted, and the uninstaller's full path
for when Settings does not list the app.


## 1.1.0

### The startup lock is now actually optional

1.0.0 described the lock as optional, but there was no way to turn it off:
if Windows Hello was configured, Noto asked for it on every launch, and the
only escape was disabling Windows Hello system-wide — a bad trade for
everything else on the machine.

A lock button in the top bar now toggles it, and the choice is remembered.
When the device has no Windows Hello or equivalent, the button is shown
disabled with an explanation rather than silently doing nothing.

The preference fails safe: a missing, unreadable, or corrupt preference file
leaves the lock on, so nothing can quietly turn it off.

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
