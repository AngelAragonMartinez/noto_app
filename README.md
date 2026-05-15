# Noto

Local notes for Linux. Encrypted vault, attachments, rich text, export to PDF/RTF/Markdown/HTML/JSON/TXT. No sync, no accounts.

Flutter + GTK. Clone, run `flutter pub get`, then `flutter run -d linux`. Release build: `flutter build linux --release`.

Binary name: `noto`. After `cmake --install`, you get a `.desktop` entry and icon under the standard XDG paths.

MIT license. Put your GitHub username in `lib/features/about/about_dialog.dart` (`kGithubUsername`).

To publish: `chmod +x scripts/publish_github.sh` then `./scripts/publish_github.sh`
(with `gh` logged in). Or create an empty `noto` repo on the site and
`git remote add origin …` + `git push -u origin main`.
