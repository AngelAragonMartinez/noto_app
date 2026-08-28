// Patches pub-cache packages that do not yet compile against the SDK and
// transitive versions this project pins. Both patches are idempotent, so the
// script is safe to run before every build.
//
// Usage:  dart run tool/patch_pub_cache.dart
//
// Remove a patch here as soon as the upstream package ships a fixed release.
import 'dart:io';

void main(List<String> args) {
  final cache = _pubCacheDir();
  if (cache == null || !cache.existsSync()) {
    stderr.writeln('!! pub cache not found; run "flutter pub get" first.');
    exit(1);
  }
  stdout.writeln(':: pub cache: ${cache.path}');

  var applied = 0;
  applied += _patchQuillNativeBridgeWindows(cache) ? 1 : 0;
  applied += _patchFlutterQuillFocus(cache) ? 1 : 0;

  stdout.writeln(
    applied == 0
        ? ':: nothing to patch (already patched, or upstream is fixed)'
        : ':: applied $applied patch(es)',
  );
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

/// Directories named `<package>-<version>`, newest-looking last.
List<Directory> _packageDirs(Directory cache, String package) {
  final hosted = Directory('${cache.path}${Platform.pathSeparator}hosted');
  if (!hosted.existsSync()) return const [];
  final result = <Directory>[];
  for (final host in hosted.listSync().whereType<Directory>()) {
    for (final entry in host.listSync().whereType<Directory>()) {
      final name = entry.uri.pathSegments
          .where((s) => s.isNotEmpty)
          .last;
      if (name.startsWith('$package-')) result.add(entry);
    }
  }
  result.sort((a, b) => a.path.compareTo(b.path));
  return result;
}

/// quill_native_bridge_windows 0.0.2 calls `GlobalAlloc(GMEM_MOVEABLE, ...)`,
/// but win32 >= 5.0 removed the `GMEM_MOVEABLE` constant. 0x0002 is its value.
bool _patchQuillNativeBridgeWindows(Directory cache) {
  var patched = false;
  for (final dir in _packageDirs(cache, 'quill_native_bridge_windows')) {
    final file = File(
      '${dir.path}${Platform.pathSeparator}lib'
      '${Platform.pathSeparator}quill_native_bridge_windows.dart',
    );
    if (!file.existsSync()) continue;

    final source = file.readAsStringSync();
    if (!source.contains('GMEM_MOVEABLE')) continue;

    file.writeAsStringSync(
      source.replaceAll('GlobalAlloc(GMEM_MOVEABLE,', 'GlobalAlloc(0x0002,'),
    );
    stdout.writeln('   patched GMEM_MOVEABLE -> 0x0002 in ${file.path}');
    patched = true;
  }
  return patched;
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
