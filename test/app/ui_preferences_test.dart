import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:notes_app/app/ui_preferences.dart';
import 'package:notes_app/core/storage/vault_paths.dart';

class _TempPaths extends VaultPaths {
  _TempPaths(this.root);

  final Directory root;

  @override
  Future<Directory> appDirectory() async => root;
}

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('noto_ui_prefs_test_');
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  group('the toolbar preference', () {
    test('starts visible', () async {
      final pref = ToolbarVisibility(paths: _TempPaths(root));
      await pref.ready;

      expect(pref.state, isTrue);
    });

    // Hiding the toolbar and finding it back on next launch is the whole point
    // of persisting it.
    test('survives a restart', () async {
      final first = ToolbarVisibility(paths: _TempPaths(root));
      await first.ready;
      await first.toggle();
      expect(first.state, isFalse);

      final second = ToolbarVisibility(paths: _TempPaths(root));
      await second.ready;

      expect(second.state, isFalse);
    });
  });

  group('the embed-images preference', () {
    // Off by default: images beside the document keep it small and leave them
    // usable on their own.
    test('starts off', () async {
      final pref = EmbedImagesOnExport(paths: _TempPaths(root));
      await pref.ready;

      expect(pref.state, isFalse);
    });

    test('survives a restart once turned on', () async {
      final first = EmbedImagesOnExport(paths: _TempPaths(root));
      await first.ready;
      await first.set(true);

      final second = EmbedImagesOnExport(paths: _TempPaths(root));
      await second.ready;

      expect(second.state, isTrue);
    });

    test('the two preferences do not share a file', () async {
      final toolbar = ToolbarVisibility(paths: _TempPaths(root));
      final embed = EmbedImagesOnExport(paths: _TempPaths(root));
      await toolbar.ready;
      await embed.ready;

      await toolbar.set(false);
      await embed.set(true);

      final reloadedToolbar = ToolbarVisibility(paths: _TempPaths(root));
      final reloadedEmbed = EmbedImagesOnExport(paths: _TempPaths(root));
      await reloadedToolbar.ready;
      await reloadedEmbed.ready;

      expect(reloadedToolbar.state, isFalse);
      expect(reloadedEmbed.state, isTrue);
    });

    // A file that cannot be read must not stop the app from starting.
    test('an unreadable file leaves the default standing', () async {
      Directory(root.path).deleteSync(recursive: true);
      final pref = ToolbarVisibility(paths: _TempPaths(root));

      await pref.ready;

      expect(pref.state, isTrue);
    });
  });
}
