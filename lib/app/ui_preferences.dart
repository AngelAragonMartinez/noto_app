import 'dart:io';

import 'package:flutter_riverpod/legacy.dart';
import 'package:path/path.dart' as p;

import '../core/storage/vault_paths.dart';

/// A yes/no preference kept as a file beside the others.
///
/// Follows [AppLockPreference]: a small file rather than a row in the vault, so
/// reading it needs no key and cannot fail because the vault is locked.
abstract class _FlagPreference extends StateNotifier<bool> {
  _FlagPreference({
    required this._fileName,
    required bool defaultValue,
    VaultPaths? paths,
  })  : _paths = paths ?? const VaultPaths(),
        super(defaultValue) {
    ready = load();
  }

  /// Completes once the stored value has been read.
  late final Future<void> ready;

  final String _fileName;
  final VaultPaths _paths;

  Future<File> _file() async {
    final dir = await _paths.appDirectory();
    return File(p.join(dir.path, _fileName));
  }

  Future<void> load() async {
    try {
      final file = await _file();
      if (await file.exists()) {
        state = (await file.readAsString()).trim() == 'on';
      }
    } catch (_) {
      // Unreadable: the default stands rather than the app refusing to start.
    }
  }

  Future<void> set(bool value) async {
    state = value;
    try {
      await (await _file()).writeAsString(value ? 'on' : 'off', flush: true);
    } catch (_) {
      // The setting still applies for this run; it just will not be remembered.
    }
  }

  Future<void> toggle() => set(!state);
}

/// Whether the formatting toolbar is showing.
class ToolbarVisibility extends _FlagPreference {
  ToolbarVisibility({super.paths})
      : super(fileName: 'toolbar_visible', defaultValue: true);
}

/// Whether exports carry their images inside the file.
///
/// Off by default: images go into the folder beside the document, which keeps
/// the document small and the images usable on their own. Turning it on trades
/// that for a single file that travels by itself.
class EmbedImagesOnExport extends _FlagPreference {
  EmbedImagesOnExport({super.paths})
      : super(fileName: 'embed_images', defaultValue: false);
}

final toolbarVisibleProvider =
    StateNotifierProvider<ToolbarVisibility, bool>((ref) {
  return ToolbarVisibility();
});

final embedImagesProvider =
    StateNotifierProvider<EmbedImagesOnExport, bool>((ref) {
  return EmbedImagesOnExport();
});
