import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:path/path.dart' as p;

import '../core/storage/vault_paths.dart';

final localeControllerProvider =
    StateNotifierProvider<LocaleController, Locale>((ref) {
  return LocaleController()..load();
});

class LocaleController extends StateNotifier<Locale> {
  LocaleController({VaultPaths? paths})
      : _paths = paths ?? const VaultPaths(),
        super(const Locale('en'));

  final VaultPaths _paths;

  Future<File> _localeFile() async {
    final dir = await _paths.appDirectory();
    return File(p.join(dir.path, 'locale'));
  }

  Future<void> load() async {
    try {
      final file = await _localeFile();
      if (await file.exists()) {
        final code = (await file.readAsString()).trim().toLowerCase();
        if (code == 'es') {
          state = const Locale('es');
          return;
        }
      }
    } catch (_) {}
    state = const Locale('en');
  }

  Future<void> setLocale(Locale locale) async {
    final code = locale.languageCode == 'es' ? 'es' : 'en';
    state = Locale(code);
    try {
      final file = await _localeFile();
      await file.writeAsString(code);
    } catch (_) {}
  }

  Future<void> toggleEnglishSpanish() async {
    await setLocale(
      state.languageCode == 'es' ? const Locale('en') : const Locale('es'),
    );
  }
}
