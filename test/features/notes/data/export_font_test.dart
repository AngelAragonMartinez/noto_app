import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_app/app/app_strings.dart';
import 'package:notes_app/core/storage/vault_paths.dart';
import 'package:notes_app/features/notes/data/note_export_repository.dart';
import 'package:notes_app/features/notes/domain/note.dart';
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
    root = Directory.systemTemp.createTempSync('noto_export_font_test_');
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Note noteWithFont() {
    final now = DateTime.utc(2026, 8, 28);
    return Note(
      id: 'n1',
      title: 'Fuentes',
      body: jsonEncode([
        {
          'insert': 'ARIALTEXT',
          'attributes': {'font': 'Arial', 'size': '24'},
        },
        {'insert': '\n'},
      ]),
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<String> exportTo(NoteExportFormat format) async {
    final repository = NoteExportRepository(paths: _TempPaths(root));
    final result = await repository.saveAt(
      noteWithFont(),
      p.join(root.path, 'out'),
      format,
      strings: AppStrings(const Locale('en')),
      includeAttachments: false,
    );
    return result.file.readAsStringSync();
  }

  test('HTML export renders the chosen font, not just mentions it', () async {
    final html = await exportTo(NoteExportFormat.html);

    expect(html, contains('ARIALTEXT'));

    // Naming the font is not enough. A bare `class="ql-font-Arial"` would
    // satisfy a substring check while rendering in the default face, because
    // the exported stylesheet does not define that class. What matters is that
    // the document actually sets a font-family the browser will apply.
    expect(
      html,
      contains('font-family'),
      reason: 'font not applied anywhere. Exported HTML was:\n$html',
    );
  });

  test('JSON export round-trips the font attribute', () async {
    final json = await exportTo(NoteExportFormat.json);

    expect(json, contains('"font"'));
    expect(json, contains('Arial'));
  });
}
