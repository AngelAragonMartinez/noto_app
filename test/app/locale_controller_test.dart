import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_app/app/locale_controller.dart';
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
    root = Directory.systemTemp.createTempSync('noto_locale_test_');
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  LocaleController controllerFor(Locale system) => LocaleController(
        paths: _TempPaths(root),
        systemLocale: system,
      );

  group('first run follows the system language', () {
    test('a Spanish system opens in Spanish', () async {
      final controller = controllerFor(const Locale('es'));
      await controller.load();

      expect(controller.state.languageCode, 'es');
    });

    test('an English system opens in English', () async {
      final controller = controllerFor(const Locale('en'));
      await controller.load();

      expect(controller.state.languageCode, 'en');
    });

    test('an untranslated system language falls back to English', () async {
      final controller = controllerFor(const Locale('ja'));
      await controller.load();

      expect(controller.state.languageCode, 'en');
    });
  });

  group('a stored choice always wins over the system', () {
    test('English stored on a Spanish system stays English', () async {
      File(p.join(root.path, 'locale')).writeAsStringSync('en');

      final controller = controllerFor(const Locale('es'));
      await controller.load();

      expect(controller.state.languageCode, 'en');
    });

    test('Spanish stored on an English system stays Spanish', () async {
      File(p.join(root.path, 'locale')).writeAsStringSync('es');

      final controller = controllerFor(const Locale('en'));
      await controller.load();

      expect(controller.state.languageCode, 'es');
    });

    test('a corrupt file falls back to the system, not to English', () async {
      File(p.join(root.path, 'locale')).writeAsStringSync('zz');

      final controller = controllerFor(const Locale('es'));
      await controller.load();

      expect(controller.state.languageCode, 'es');
    });
  });

  test('choosing a language persists it', () async {
    final controller = controllerFor(const Locale('en'));
    await controller.load();
    await controller.setLocale(const Locale('es'));

    expect(File(p.join(root.path, 'locale')).readAsStringSync(), 'es');

    final reloaded = controllerFor(const Locale('en'));
    await reloaded.load();
    expect(reloaded.state.languageCode, 'es');
  });
}
