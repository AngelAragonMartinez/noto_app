import 'dart:io';

import 'package:flutter_riverpod/legacy.dart';
import 'package:path/path.dart' as p;

import '../storage/vault_paths.dart';

/// Whether the startup lock is on.
///
/// Kept as a file next to the other preferences rather than in the vault: the
/// gate has to answer before anything is decrypted, so this must be readable
/// without a key.
final appLockEnabledProvider =
    StateNotifierProvider<AppLockPreference, bool>((ref) {
  return AppLockPreference();
});

class AppLockPreference extends StateNotifier<bool> {
  AppLockPreference({VaultPaths? paths})
      : _paths = paths ?? const VaultPaths(),
        // On until proven otherwise. A missing or unreadable file must not be
        // a way to end up with the lock silently off.
        super(true) {
    ready = load();
  }

  /// Completes once the stored preference has been read.
  ///
  /// AppLockGate must await this: reading the state before the file has been
  /// loaded would see the safe default and prompt even when the user turned
  /// the lock off.
  late final Future<void> ready;

  final VaultPaths _paths;

  Future<File> _preferenceFile() async {
    final dir = await _paths.appDirectory();
    return File(p.join(dir.path, 'app_lock'));
  }

  Future<void> load() async {
    try {
      final file = await _preferenceFile();
      if (await file.exists()) {
        state = (await file.readAsString()).trim() != 'off';
        return;
      }
    } catch (_) {}
    state = true;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    try {
      await (await _preferenceFile()).writeAsString(enabled ? 'on' : 'off');
    } catch (_) {}
  }

  Future<void> toggle() => setEnabled(!state);
}
