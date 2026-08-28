import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:notes_app/core/security/app_lock_preference.dart';
import 'package:notes_app/core/storage/vault_paths.dart';
import 'package:path/path.dart' as p;

class _TempPaths extends VaultPaths {
  _TempPaths(this.root);

  final Directory root;

  @override
  Future<Directory> appDirectory() async => root;
}

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('noto_app_lock_test_');
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  File preferenceFile() => File(p.join(root.path, 'app_lock'));

  test('defaults to enabled when nothing is stored', () async {
    final preference = AppLockPreference(paths: _TempPaths(root));
    await preference.ready;

    expect(preference.debugState, isTrue);
  });

  test('persists being turned off, and reads back off', () async {
    final preference = AppLockPreference(paths: _TempPaths(root));
    await preference.ready;
    await preference.setEnabled(false);

    expect(preferenceFile().readAsStringSync(), 'off');

    final reloaded = AppLockPreference(paths: _TempPaths(root));
    await reloaded.ready;
    expect(reloaded.debugState, isFalse);
  });

  test('turning it back on persists too', () async {
    final preference = AppLockPreference(paths: _TempPaths(root));
    await preference.ready;
    await preference.setEnabled(false);
    await preference.setEnabled(true);

    final reloaded = AppLockPreference(paths: _TempPaths(root));
    await reloaded.ready;
    expect(reloaded.debugState, isTrue);
  });

  test('an unreadable or corrupt file leaves the lock ON', () async {
    // Fails safe: garbage in the file must never be a way to silently end up
    // with no lock at all.
    preferenceFile().writeAsStringSync('\u0000garbage\u0000');

    final preference = AppLockPreference(paths: _TempPaths(root));
    await preference.ready;

    expect(preference.debugState, isTrue);
  });

  test('toggle flips and persists', () async {
    final preference = AppLockPreference(paths: _TempPaths(root));
    await preference.ready;

    await preference.toggle();
    expect(preference.debugState, isFalse);
    expect(preferenceFile().readAsStringSync(), 'off');

    await preference.toggle();
    expect(preference.debugState, isTrue);
    expect(preferenceFile().readAsStringSync(), 'on');
  });
}
