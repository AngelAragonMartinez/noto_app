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
    root = Directory.systemTemp.createTempSync('noto_export_integrity_');
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Note sampleNote() {
    final now = DateTime.utc(2026, 8, 29);
    return Note(
      id: 'n1',
      title: 'Reunión',
      body: jsonEncode([
        {'insert': 'Acentos y eñes: canción, mañana.\n'},
      ]),
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<File> saveAs(String fileName, NoteExportFormat format) async {
    final result = await NoteExportRepository(paths: _TempPaths(root)).saveAt(
      sampleNote(),
      p.join(root.path, fileName),
      format,
      strings: AppStrings(const Locale('en')),
      includeAttachments: false,
    );
    return result.file;
  }

  group('the saved file always ends with the extension matching its contents',
      () {
    test('a name containing a dot still gets its extension', () async {
      // "Reunión 20.08" looks like it already has an extension (".08"), which
      // is why files like this were saved unusable and reported as damaged.
      final file = await saveAs('Reunión 20.08', NoteExportFormat.txt);

      expect(p.extension(file.path), '.txt');
    });

    test('a mismatched extension is corrected, not trusted', () async {
      final file = await saveAs('notas.txt', NoteExportFormat.pdf);

      expect(p.extension(file.path), '.pdf');
    });

    test('a correct extension is left alone', () async {
      final file = await saveAs('notas.txt', NoteExportFormat.txt);

      expect(p.basename(file.path), 'notas.txt');
    });

    test('extension matching ignores case', () async {
      final file = await saveAs('NOTAS.TXT', NoteExportFormat.txt);

      expect(p.basename(file.path), 'NOTAS.TXT');
    });
  });

  group('each format writes what its extension promises', () {
    test('txt is readable UTF-8 text, accents intact', () async {
      final file = await saveAs('nota', NoteExportFormat.txt);

      final text = utf8.decode(file.readAsBytesSync());
      expect(text, contains('canción'));
      expect(text, contains('mañana'));
    });

    test('pdf carries the PDF signature', () async {
      final file = await saveAs('nota', NoteExportFormat.pdf);

      expect(String.fromCharCodes(file.readAsBytesSync().take(5)), '%PDF-');
    });

    test('rtf carries the RTF signature', () async {
      final file = await saveAs('nota', NoteExportFormat.rtf);

      expect(file.readAsStringSync(), startsWith(r'{\rtf1'));
    });

    test('html is a complete document', () async {
      final file = await saveAs('nota', NoteExportFormat.html);

      final html = file.readAsStringSync();
      expect(html, startsWith('<!doctype html>'));
      expect(html, contains('</html>'));
    });

    test('json parses and keeps the note fields', () async {
      final file = await saveAs('nota', NoteExportFormat.json);

      final decoded = jsonDecode(file.readAsStringSync()) as Map;
      expect(decoded['title'], 'Reunión');
      expect(decoded['body'], isA<List>());
    });

    test('markdown leads with the title as a heading', () async {
      final file = await saveAs('nota', NoteExportFormat.markdown);

      expect(file.readAsStringSync(), startsWith('# Reunión'));
    });
  });
}
