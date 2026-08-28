import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:path/path.dart' as p;

import '../../core/storage/vault_paths.dart';

enum WelcomeStatus { loading, show, hide }

final welcomeControllerProvider =
    StateNotifierProvider<WelcomeController, WelcomeStatus>((ref) {
  return WelcomeController();
});

class WelcomeController extends StateNotifier<WelcomeStatus> {
  WelcomeController({VaultPaths? paths})
      : _paths = paths ?? const VaultPaths(),
        super(WelcomeStatus.loading) {
    scheduleMicrotask(load);
    WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }

  final VaultPaths _paths;

  static const String _legacyMarkerName = '.welcome_done';
  static const String _completeMarkerName = '.noto_welcome_complete';

  Future<File> _completeMarkerFile() async {
    final dir = await _paths.appDirectory();
    return File(p.join(dir.path, _completeMarkerName));
  }

  Future<File> _legacyMarkerFile() async {
    final dir = await _paths.appDirectory();
    return File(p.join(dir.path, _legacyMarkerName));
  }

  Future<void> load() async {
    try {
      final complete = await _completeMarkerFile();
      if (kDebugMode) {
        debugPrint(
            '[Noto] welcome marker: ${complete.path} exists=${await complete.exists()}');
      }
      if (await complete.exists()) {
        state = WelcomeStatus.hide;
        return;
      }
      state = WelcomeStatus.show;
    } catch (_) {
      state = WelcomeStatus.show;
    }
  }

  Future<void> dismiss() async {
    try {
      final complete = await _completeMarkerFile();
      if (!await complete.exists()) {
        await complete.writeAsString(DateTime.now().toUtc().toIso8601String());
      }
      final legacy = await _legacyMarkerFile();
      if (await legacy.exists()) {
        await legacy.delete();
      }
    } catch (_) {}
    state = WelcomeStatus.hide;
  }
}
