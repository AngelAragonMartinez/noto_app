import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:path/path.dart' as p;

import '../core/storage/vault_paths.dart';

final localeControllerProvider =
    StateNotifierProvider<LocaleController, Locale>((ref) {
  return LocaleController()..load();
});

class LocaleController extends StateNotifier<Locale> {
  LocaleController({VaultPaths? paths, this._systemLocale})
      : _paths = paths ?? const VaultPaths(),
        super(const Locale('en'));

  final VaultPaths _paths;
  final Locale? _systemLocale;

  /// The languages Noto has translations for.
  static const supported = {'en', 'es'};

  Future<File> _localeFile() async {
    final dir = await _paths.appDirectory();
    return File(p.join(dir.path, 'locale'));
  }

  /// Language to start in when the user has never chosen one.
  ///
  /// Follows the operating system. Noto previously always opened in English,
  /// so a Spanish system got an English welcome screen and had to reach for the
  /// language button before reading anything.
  @visibleForTesting
  Locale initialLocale() {
    final code = (_systemLocale ?? ui.PlatformDispatcher.instance.locale)
        .languageCode
        .toLowerCase();
    return supported.contains(code) ? Locale(code) : const Locale('en');
  }

  Future<void> load() async {
    try {
      final file = await _localeFile();
      if (await file.exists()) {
        final code = (await file.readAsString()).trim().toLowerCase();
        if (supported.contains(code)) {
          state = Locale(code);
          return;
        }
      }
    } catch (_) {}
    // No stored choice: follow the system rather than assuming English.
    state = initialLocale();
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
