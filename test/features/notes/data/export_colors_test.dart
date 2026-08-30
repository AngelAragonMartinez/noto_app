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
    root = Directory.systemTemp.createTempSync('noto_export_colors_test_');
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  // Red text on a yellow highlight — the combination users report losing.
  Note colouredNote() {
    final now = DateTime.utc(2026, 8, 29);
    return Note(
      id: 'n1',
      title: 'Colores',
      body: jsonEncode([
        {
          'insert': 'ROJO',
          'attributes': {'color': '#ff0000'},
        },
        {
          'insert': 'REMARCADO',
          'attributes': {'background': '#ffff00'},
        },
        {'insert': '\n'},
      ]),
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<String> exportTo(NoteExportFormat format) async {
    final result = await NoteExportRepository(paths: _TempPaths(root)).saveAt(
      colouredNote(),
      p.join(root.path, 'out'),
      format,
      strings: AppStrings(const Locale('en')),
      includeAttachments: false,
    );
    return result.file.readAsStringSync();
  }

  group('colour survives export', () {
    test('RTF declares both colours and applies them', () async {
      final rtf = await exportTo(NoteExportFormat.rtf);

      // Red and yellow must appear in the colour table...
      expect(rtf, contains(r'\red255\green0\blue0'));
      expect(rtf, contains(r'\red255\green255\blue0'));
      // ...and be referenced, or the table is just decoration. `contains`
      // rather than `matches`: matches requires the whole string to be the
      // pattern, which is never true of a document.
      expect(rtf.contains(RegExp(r'\\cf[2-9]')), isTrue, reason: rtf);
      expect(rtf.contains(RegExp(r'\\highlight[2-9]')), isTrue, reason: rtf);
    });

    test('Markdown emits colour and background styles', () async {
      final md = await exportTo(NoteExportFormat.markdown);

      expect(md, contains('color:#ff0000'));
      expect(md, contains('background-color:#ffff00'));
    });

    test('HTML keeps both', () async {
      final html = await exportTo(NoteExportFormat.html);

      expect(html.toLowerCase(), contains('ff0000'));
      expect(html.toLowerCase(), contains('ffff00'));
    });

    test('JSON round-trips both attributes', () async {
      final json = await exportTo(NoteExportFormat.json);

      expect(json, contains('"color"'));
      expect(json, contains('"background"'));
    });
  });

  group('colour parsing', () {
    test('accepts the shapes an editor or paste can produce', () {
      expect(NoteExportRepository.normaliseColor('#FF0000'), '#ff0000');
      expect(NoteExportRepository.normaliseColor('ff0000'), '#ff0000');
      expect(NoteExportRepository.normaliseColor('#f00'), '#ff0000');
      expect(NoteExportRepository.normaliseColor('rgb(255, 0, 0)'), '#ff0000');
      expect(
        NoteExportRepository.normaliseColor('rgba(255, 0, 0, 0.5)'),
        '#ff0000',
      );
      // #aarrggbb: alpha dropped, no export format here can show it
      expect(NoteExportRepository.normaliseColor('#80ff0000'), '#ff0000');
    });

    test('rejects what it cannot represent, rather than guessing', () {
      expect(NoteExportRepository.normaliseColor(''), isNull);
      expect(NoteExportRepository.normaliseColor('transparent'), isNull);
      expect(NoteExportRepository.normaliseColor('chartreuse'), isNull);
      expect(NoteExportRepository.normaliseColor('#12345'), isNull);
      expect(NoteExportRepository.normaliseColor('rgb(300,0,0)'), isNull);
    });
  });
}
