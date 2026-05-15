import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/storage/vault_paths.dart';

/// Remembers import paths for the Open ▸ Recent list (max 12).
class RecentNoteImportsStore {
  RecentNoteImportsStore({VaultPaths? paths})
      : _paths = paths ?? const VaultPaths();

  final VaultPaths _paths;
  static const _max = 12;

  Future<File> _storeFile() async {
    final dir = await _paths.appDirectory();
    return File(p.join(dir.path, 'recent_note_imports.json'));
  }

  Future<List<String>> readPaths() async {
    try {
      final file = await _storeFile();
      if (!await file.exists()) return [];
      final list = jsonDecode(await file.readAsString()) as List<dynamic>;
      return list
          .whereType<String>()
          .where((path) => path.isNotEmpty)
          .take(_max)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> prepend(String path) async {
    if (path.isEmpty) return;
    final current = await readPaths();
    final next = [path, ...current.where((p) => p != path)].take(_max).toList();
    await (await _storeFile()).writeAsString(jsonEncode(next));
  }

  Future<void> remove(String path) async {
    final current = await readPaths();
    await (await _storeFile())
        .writeAsString(jsonEncode(current.where((p) => p != path).toList()));
  }
}
