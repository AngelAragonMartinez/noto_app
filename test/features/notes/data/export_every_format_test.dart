import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_app/app/app_strings.dart';
import 'package:notes_app/core/security/secure_key_store.dart';
import 'package:notes_app/core/storage/vault_paths.dart';
import 'package:notes_app/features/documents/data/document_repository.dart';
import 'package:notes_app/features/notes/data/note_export_repository.dart';
import 'package:notes_app/features/notes/domain/note.dart';
import 'package:path/path.dart' as p;

class _TempPaths extends VaultPaths {
  _TempPaths(this.root);

  final Directory root;

  @override
  Future<Directory> appDirectory() async => root;
}

class _FixedKeyStore extends SecureKeyStore {
  @override
  Future<List<int>> readOrCreateDocumentKey() async => List<int>.filled(32, 9);

  @override
  Future<List<int>> readOrCreateVaultKey() async => List<int>.filled(32, 8);
}

void main() {
  late Directory vault;
  late Directory out;
  late NoteExportRepository exporter;
  late DocumentRepository documents;

  setUp(() {
    vault = Directory.systemTemp.createTempSync('noto_fmt_vault_');
    out = Directory.systemTemp.createTempSync('noto_fmt_out_');
    documents = DocumentRepository(
      paths: _TempPaths(vault),
      keyStore: _FixedKeyStore(),
    );
    exporter =
        NoteExportRepository(paths: _TempPaths(vault), documents: documents);
  });

  tearDown(() {
    for (final d in [vault, out]) {
      if (d.existsSync()) d.deleteSync(recursive: true);
    }
  });

  Note plainNote() => Note(
        id: 'n1',
        title: 'Informe',
        body: jsonEncode([
          {'insert': 'Cuerpo de la nota'},
          {
            'insert': '\n',
            'attributes': {'header': 1},
          },
          {'insert': 'Un parrafo normal.\n'},
        ]),
        createdAt: DateTime.utc(2026, 9, 4),
        updatedAt: DateTime.utc(2026, 9, 4),
      );

  Future<File> exportTo(NoteExportFormat format) async {
    final result = await exporter.saveAt(
      plainNote(),
      p.join(out.path, 'informe'),
      format,
      strings: AppStrings(const Locale('en')),
      includeAttachments: false,
    );
    return result.file;
  }

  group('every format writes its own kind of file', () {
    // Choosing Markdown once produced a .txt: the format was decided by a
    // suggested name rather than the choice. These pin each format to both the
    // extension it claims and the content it should hold.
    test('the extension matches the format asked for', () async {
      for (final format in NoteExportFormat.values) {
        final file = await exportTo(format);
        expect(p.extension(file.path), '.${format.extension}',
            reason: format.name);
        expect(file.existsSync(), isTrue, reason: format.name);
      }
    });

    test('and the contents are really that format', () async {
      final md = (await exportTo(NoteExportFormat.markdown)).readAsStringSync();
      expect(md, contains('# '), reason: 'markdown heading');

      final html = (await exportTo(NoteExportFormat.html)).readAsStringSync();
      expect(html.toLowerCase(), contains('<html'), reason: 'html document');

      final rtf = (await exportTo(NoteExportFormat.rtf)).readAsStringSync();
      expect(rtf.startsWith(r'{\rtf'), isTrue, reason: 'rtf signature');

      final pdf = (await exportTo(NoteExportFormat.pdf)).readAsBytesSync();
      expect(String.fromCharCodes(pdf.take(5)), '%PDF-', reason: 'pdf header');

      final json = (await exportTo(NoteExportFormat.json)).readAsStringSync();
      expect(jsonDecode(json), isA<Map<String, dynamic>>());

      // Plain text must stay plain: no markup leaking in from a sibling format.
      final txt = (await exportTo(NoteExportFormat.txt)).readAsStringSync();
      expect(txt, contains('Cuerpo de la nota'));
      expect(txt, isNot(contains('<')));
      expect(txt, isNot(contains(r'\rtf')));
    });
  });

  group('exports do not carry more weight than they need', () {
    test('a note without images stays small in every format', () async {
      for (final format in NoteExportFormat.values) {
        final size = (await exportTo(format)).lengthSync();
        expect(size, lessThan(120 * 1024), reason: '${format.name}: $size B');
      }
    });

    // Base64 in the document was what made an exported note weigh several
    // times the note itself.
    test('an image goes beside the document, not inside it', () async {
      final png = Uint8List.fromList(
        [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
         ...List<int>.generate(400 * 1024, (i) => i % 251)],
      );
      final src =
          await documents.storeInlineImageBytes(png, fileExtension: '.png');
      final withImage = Note(
        id: 'n2',
        title: 'Con foto',
        body: jsonEncode([
          {'insert': 'Antes\n'},
          {
            'insert': {'image': src},
          },
          {'insert': '\n'},
        ]),
        createdAt: DateTime.utc(2026, 9, 4),
        updatedAt: DateTime.utc(2026, 9, 4),
      );

      for (final format in [
        NoteExportFormat.markdown,
        NoteExportFormat.html,
        NoteExportFormat.json,
      ]) {
        final result = await exporter.saveAt(
          withImage,
          p.join(out.path, 'foto-${format.name}'),
          format,
          strings: AppStrings(const Locale('en')),
          includeAttachments: false,
        );
        final size = result.file.lengthSync();
        expect(size, lessThan(png.length ~/ 4),
            reason: '${format.name} carries the image: $size B');
      }
    });
  });
}
