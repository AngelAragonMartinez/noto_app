import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:path/path.dart' as p;

import '../core/storage/vault_paths.dart';

/// What the user picked, which is not the same as what gets painted.
///
/// [byTime] resolves to light or dark from the clock, so it needs a choice of
/// its own: storing the resolved mode would lose the fact that it should keep
/// following the hour.
enum NotoTheme { system, light, dark, byTime }

/// Dark in the evening and overnight, light through the day.
///
/// The boundaries are deliberately blunt. Anything finer means asking for a
/// location to work out sunset, and a notes app has no business doing that.
ThemeMode themeModeAt(DateTime time) =>
    (time.hour >= 19 || time.hour < 7) ? ThemeMode.dark : ThemeMode.light;

/// The next moment [themeModeAt] returns something different.
DateTime nextThemeChangeAfter(DateTime time) {
  final today = DateTime(time.year, time.month, time.day);
  final morning = today.add(const Duration(hours: 7));
  final evening = today.add(const Duration(hours: 19));
  if (time.isBefore(morning)) return morning;
  if (time.isBefore(evening)) return evening;
  return morning.add(const Duration(days: 1));
}

class ThemeController extends StateNotifier<NotoTheme> {
  ThemeController({VaultPaths? paths})
      : _paths = paths ?? const VaultPaths(),
        super(NotoTheme.system) {
    ready = load();
  }

  /// Completes once the stored choice has been read.
  late final Future<void> ready;

  final VaultPaths _paths;
  Timer? _timer;

  Future<File> _file() async {
    final dir = await _paths.appDirectory();
    return File(p.join(dir.path, 'theme'));
  }

  Future<void> load() async {
    try {
      final file = await _file();
      if (await file.exists()) {
        final stored = (await file.readAsString()).trim();
        state = NotoTheme.values.firstWhere(
          (t) => t.name == stored,
          orElse: () => NotoTheme.system,
        );
      }
    } catch (_) {
      // Unreadable: the system default stands.
    }
    _scheduleTick();
  }

  Future<void> set(NotoTheme choice) async {
    state = choice;
    _scheduleTick();
    try {
      await (await _file()).writeAsString(choice.name, flush: true);
    } catch (_) {
      // Applies for this run; it just will not be remembered.
    }
  }

  /// system → light → dark → by time → system.
  Future<void> cycle() => set(
        NotoTheme.values[(state.index + 1) % NotoTheme.values.length],
      );

  /// Wakes up when the clock is due to flip the theme, and not before.
  ///
  /// A periodic tick would spend the whole day asking what time it is to change
  /// its mind twice.
  void _scheduleTick() {
    _timer?.cancel();
    if (state != NotoTheme.byTime) return;
    final now = DateTime.now();
    final wait = nextThemeChangeAfter(now).difference(now);
    _timer = Timer(wait + const Duration(seconds: 1), () {
      if (!mounted) return;
      state = NotoTheme.byTime; // same choice, new resolved mode
      _scheduleTick();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final themeChoiceProvider =
    StateNotifierProvider<ThemeController, NotoTheme>((ref) {
  return ThemeController();
});

/// What actually gets painted.
final themeModeProvider = Provider<ThemeMode>((ref) {
  return switch (ref.watch(themeChoiceProvider)) {
    NotoTheme.system => ThemeMode.system,
    NotoTheme.light => ThemeMode.light,
    NotoTheme.dark => ThemeMode.dark,
    NotoTheme.byTime => themeModeAt(DateTime.now()),
  };
});
