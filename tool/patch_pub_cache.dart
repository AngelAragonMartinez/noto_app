// Patches pub-cache packages that do not yet compile against the SDK and
// transitive versions this project pins. The patch is idempotent, so the
// script is safe to run before every build.
//
// Usage:  dart run tool/patch_pub_cache.dart
//
// Remove a patch here as soon as the upstream package ships a fixed release.
//
// Previously this also rewrote quill_native_bridge_windows 0.0.2, which called
// GlobalAlloc with win32 5's removed GMEM_MOVEABLE constant. Dropping the
// `dependency_overrides` entry let pub resolve 0.1.0, which moved to win32 6
// and takes a typed GLOBAL_ALLOC_FLAGS — so the old rewrite went from
// necessary to actively breaking correct code, and is gone.
import 'dart:io';

void main(List<String> args) {
  final cache = _pubCacheDir();
  if (cache == null || !cache.existsSync()) {
    stderr.writeln('!! pub cache not found; run "flutter pub get" first.');
    exit(1);
  }
  stdout.writeln(':: pub cache: ${cache.path}');

  var applied = 0;
  applied += _patchFlutterQuillFocus(cache) ? 1 : 0;
  applied += _patchLocalAuthWindowsAwait(cache) ? 1 : 0;
  applied += _patchQuillWindowsClipboard(cache) ? 1 : 0;

  stdout.writeln(
    applied == 0
        ? ':: nothing to patch (already patched, or upstream is fixed)'
        : ':: applied $applied patch(es)',
  );
}

/// local_auth_windows builds with `/await`, MSVC's pre-standard coroutine
/// switch, which forces `<experimental/coroutine>`. Current MSVC toolsets
/// reject that header outright (STL1011), failing the plugin build.
///
/// The flag is simply obsolete: the same CMakeLists already requests
/// `cxx_std_20`, and C++20 has coroutines in the language, so dropping
/// `/await` makes C++/WinRT use the standard `<coroutine>` instead. This
/// removes the deprecated code path rather than silencing the warning about
/// it.
/// Dropping the flag then exposes a second problem: under `/await`'s relaxed
/// rules the plugin returns from a coroutine with plain `return`, which
/// standard C++20 rejects (C3773). Upstream has already switched that line to
/// `co_return` on main; 2.0.2 predates the change.
bool _patchLocalAuthWindowsAwait(Directory cache) {
  var patched = false;
  for (final dir in _packageDirs(cache, 'local_auth_windows')) {
    final sep = Platform.pathSeparator;

    final cmake = File('${dir.path}${sep}windows${sep}CMakeLists.txt');
    if (cmake.existsSync()) {
      final source = cmake.readAsStringSync();
      final awaitLine = RegExp(
        r'^[ \t]*target_compile_options\([^)]*?/await[^)]*\)[ \t]*\r?\n',
        multiLine: true,
      );
      if (awaitLine.hasMatch(source)) {
        cmake.writeAsStringSync(source.replaceAll(awaitLine, ''));
        stdout.writeln('   removed /await from ${cmake.path}');
        patched = true;
      }
    }

    final plugin = File('${dir.path}${sep}windows${sep}local_auth_plugin.cpp');
    if (plugin.existsSync()) {
      final source = plugin.readAsStringSync();
      // The only `return` inside a coroutine here: the surrounding function
      // co_awaits RequestVerificationForWindowAsync. Every other `return` in
      // the file is in an ordinary function and must stay as it is.
      const from = 'return consent_result;';
      const to = 'co_return consent_result;';
      if (source.contains(from) && !source.contains(to)) {
        plugin.writeAsStringSync(source.replaceAll(from, to));
        stdout.writeln('   return -> co_return in ${plugin.path}');
        patched = true;
      }
    }
  }
  return patched;
}

/// quill_native_bridge_windows destroys the clipboard when copying.
///
/// `copyHtmlToClipboard` calls `EmptyClipboard()` and then writes only
/// `CF_HTML`. Flutter has already placed the plain text via `Clipboard.setData`
/// at that point, so the wipe removes it and nothing but HTML is left. Copying
/// from the note body therefore yields a clipboard that plain-text consumers —
/// the title field, other applications — read as empty.
///
/// Its error handling is `assert(false, ...)` throughout, which release builds
/// strip, so every failure is silent for the people affected.
///
/// Dropping the feature from `isSupported` makes flutter_quill fall back to
/// Flutter's own clipboard, which writes plain text and never empties anything.
/// The cost is that copying out of Noto no longer carries formatting to other
/// applications; the gain is that copying works at all. Reading HTML from the
/// clipboard is left enabled — it only reads, so pasting formatted content in
/// still works.
///
/// The package describes itself as "Highly Experimental" and carries a TODO to
/// test clipboard behaviour against other Windows applications.
bool _patchQuillWindowsClipboard(Directory cache) {
  var patched = false;
  for (final dir in _packageDirs(cache, 'quill_native_bridge_windows')) {
    final sep = Platform.pathSeparator;
    final file = File(
      '${dir.path}${sep}lib${sep}quill_native_bridge_windows.dart',
    );
    if (!file.existsSync()) continue;

    final source = file.readAsStringSync();
    final entry = RegExp(
      r'^[ \t]*QuillNativeBridgeFeature\.copyHtmlToClipboard,[ \t]*\r?\n',
      multiLine: true,
    );
    if (!entry.hasMatch(source)) continue;

    file.writeAsStringSync(source.replaceAll(entry, ''));
    stdout.writeln('   disabled copyHtmlToClipboard in ${file.path}');
    patched = true;
  }
  return patched;
}

/// `$PUB_CACHE`, else the platform default.
Directory? _pubCacheDir() {
  final env = Platform.environment['PUB_CACHE'];
  if (env != null && env.isNotEmpty) return Directory(env);

  if (Platform.isWindows) {
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData == null) return null;
    return Directory('$localAppData/Pub/Cache');
  }
  final home = Platform.environment['HOME'];
  if (home == null) return null;
  return Directory('$home/.pub-cache');
}

/// Directories named `<package>-<version>`.
List<Directory> _packageDirs(Directory cache, String package) {
  final hosted = Directory('${cache.path}${Platform.pathSeparator}hosted');
  if (!hosted.existsSync()) return const [];
  final result = <Directory>[];
  for (final host in hosted.listSync().whereType<Directory>()) {
    for (final entry in host.listSync().whereType<Directory>()) {
      final name = entry.uri.pathSegments.where((s) => s.isNotEmpty).last;
      if (name.startsWith('$package-')) result.add(entry);
    }
  }
  result.sort((a, b) => a.path.compareTo(b.path));
  return result;
}

/// flutter_quill <= 11.5.1 does not implement `TextInputClient.onFocusReceived`,
/// which Flutter >= 3.44.0 made a required member.
bool _patchFlutterQuillFocus(Directory cache) {
  var patched = false;
  for (final dir in _packageDirs(cache, 'flutter_quill')) {
    final sep = Platform.pathSeparator;
    final file = File(
      '${dir.path}${sep}lib${sep}src${sep}editor${sep}raw_editor'
      '${sep}raw_editor_state.dart',
    );
    if (!file.existsSync()) continue;

    final source = file.readAsStringSync();
    if (source.contains('onFocusReceived')) continue;

    final classAt = source.indexOf('class QuillRawEditorState');
    if (classAt < 0) {
      stderr.writeln('   !! QuillRawEditorState not found in ${file.path}');
      continue;
    }
    final braceAt = source.indexOf('{', classAt);
    if (braceAt < 0) {
      stderr.writeln('   !! class body not found in ${file.path}');
      continue;
    }

    file.writeAsStringSync(
      '${source.substring(0, braceAt + 1)}\n'
      '  @override\n'
      '  bool onFocusReceived() => false;\n'
      '${source.substring(braceAt + 1)}',
    );
    stdout.writeln('   added onFocusReceived() to ${file.path}');
    patched = true;
  }
  return patched;
}
