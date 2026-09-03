import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_app/app/theme_controller.dart';
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
    root = Directory.systemTemp.createTempSync('noto_theme_test_');
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  group('automatic by time of day', () {
    ThemeMode at(int hour) => themeModeAt(DateTime(2026, 9, 3, hour));

    test('light through the day, dark in the evening and overnight', () {
      expect(at(7), ThemeMode.light, reason: 'the moment it turns light');
      expect(at(12), ThemeMode.light);
      expect(at(18), ThemeMode.light, reason: 'still light at 18:59');
      expect(at(19), ThemeMode.dark, reason: 'the moment it turns dark');
      expect(at(23), ThemeMode.dark);
      expect(at(0), ThemeMode.dark);
      expect(at(6), ThemeMode.dark, reason: 'still dark at 06:59');
    });

    // The controller sleeps until the next flip rather than polling, so this
    // has to land exactly on the boundary.
    test('the next change lands on the next boundary', () {
      DateTime next(int hour, [int minute = 0]) =>
          nextThemeChangeAfter(DateTime(2026, 9, 3, hour, minute));

      expect(next(3), DateTime(2026, 9, 3, 7), reason: 'before morning');
      expect(next(7, 1), DateTime(2026, 9, 3, 19), reason: 'during the day');
      expect(next(21), DateTime(2026, 9, 4, 7), reason: 'rolls to tomorrow');
    });

    test('the boundary it returns really does change the mode', () {
      for (final hour in [3, 10, 21]) {
        final now = DateTime(2026, 9, 3, hour);
        final flip = nextThemeChangeAfter(now);
        expect(themeModeAt(now), isNot(themeModeAt(flip)), reason: '$hour h');
      }
    });
  });

  group('the stored choice', () {
    test('starts on the system theme', () async {
      final controller = ThemeController(paths: _TempPaths(root));
      await controller.ready;

      expect(controller.state, NotoTheme.system);
    });

    test('survives a restart', () async {
      final first = ThemeController(paths: _TempPaths(root));
      await first.ready;
      await first.set(NotoTheme.byTime);
      first.dispose();

      final second = ThemeController(paths: _TempPaths(root));
      await second.ready;

      expect(second.state, NotoTheme.byTime);
      second.dispose();
    });

    // Storing the resolved light/dark would lose the fact that it should keep
    // following the clock.
    test('remembers the choice, not the mode it resolved to', () async {
      final controller = ThemeController(paths: _TempPaths(root));
      await controller.ready;
      await controller.set(NotoTheme.byTime);

      final stored = File('${root.path}/theme').readAsStringSync().trim();

      expect(stored, 'byTime');
      controller.dispose();
    });

    test('cycles through all four and comes back round', () async {
      final controller = ThemeController(paths: _TempPaths(root));
      await controller.ready;

      final seen = <NotoTheme>[controller.state];
      for (var i = 0; i < NotoTheme.values.length; i++) {
        await controller.cycle();
        seen.add(controller.state);
      }

      expect(seen.first, seen.last, reason: 'returns to where it started');
      expect(seen.toSet(), NotoTheme.values.toSet(), reason: 'visits them all');
      controller.dispose();
    });

    test('an unrecognised stored value falls back to the system theme', () async {
      File('${root.path}/theme').writeAsStringSync('sepia');

      final controller = ThemeController(paths: _TempPaths(root));
      await controller.ready;

      expect(controller.state, NotoTheme.system);
      controller.dispose();
    });
  });
}
