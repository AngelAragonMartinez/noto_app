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

/// Avoids touching the OS keyring in tests.
class _FixedKeyStore extends SecureKeyStore {
  @override
  Future<List<int>> readOrCreateDocumentKey() async => List<int>.filled(32, 9);

  @override
  Future<List<int>> readOrCreateVaultKey() async => List<int>.filled(32, 8);
}

void main() {
  late Directory vault;
  late Directory outDir;
  late DocumentRepository documents;
  late NoteExportRepository exporter;
  late String imageSource;

  // A PNG signature, so the written file is unmistakably the image.
  final pngBytes = Uint8List.fromList(
    [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3, 4, 5],
  );

  setUp(() async {
    vault = Directory.systemTemp.createTempSync('noto_export_images_vault_');
    outDir = Directory.systemTemp.createTempSync('noto_export_images_out_');
    documents = DocumentRepository(
      paths: _TempPaths(vault),
      keyStore: _FixedKeyStore(),
    );
    exporter = NoteExportRepository(
      paths: _TempPaths(vault),
      documents: documents,
    );
    imageSource = await documents.storeInlineImageBytes(
      pngBytes,
      fileExtension: '.png',
    );
  });

  tearDown(() {
    for (final d in [vault, outDir]) {
      if (d.existsSync()) d.deleteSync(recursive: true);
    }
  });

  Note noteWithImage() {
    final now = DateTime.utc(2026, 9, 1);
    return Note(
      id: 'n1',
      title: 'Con imagen',
      body: jsonEncode([
        {'insert': 'Antes\n'},
        {
          'insert': {'image': imageSource},
        },
        {'insert': '\nDespues\n'},
      ]),
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<String> exportTo(NoteExportFormat format, {bool embed = false}) async {
    final result = await exporter.saveAt(
      noteWithImage(),
      p.join(outDir.path, 'nota'),
      format,
      strings: AppStrings(const Locale('en')),
      includeAttachments: false,
      embedImages: embed,
    );
    return result.file.readAsStringSync();
  }

  Directory sidecar() => Directory(p.join(outDir.path, 'nota-adjuntos'));

  group('inline images are written beside the document', () {
    // Base64 inflates an image by a third and buries the text under encoded
    // blocks, which is what made exported notes so much heavier than the note.
    test('Markdown links the file instead of inlining base64', () async {
      final md = await exportTo(NoteExportFormat.markdown);

      expect(md, isNot(contains('base64')));
      expect(md, contains('nota-adjuntos/'));
      final written = sidecar().listSync().whereType<File>().toList();
      expect(written, hasLength(1));
      expect(written.single.readAsBytesSync(), pngBytes);
    });

    test('HTML points at the same file', () async {
      final html = await exportTo(NoteExportFormat.html);

      expect(html, isNot(contains('base64')));
      expect(html, contains('nota-adjuntos/'));
    });

    // JSON never inlined anything: it kept an absolute path into the vault,
    // which means nothing on another machine and nothing here once the note is
    // gone.
    test('JSON carries a relative path, not one into the vault', () async {
      final json = await exportTo(NoteExportFormat.json);

      expect(json, contains('nota-adjuntos/'));
      expect(json, isNot(contains(vault.path)));
    });

    test('asking to embed brings base64 back', () async {
      final md = await exportTo(NoteExportFormat.markdown, embed: true);

      expect(md, contains('base64'));
      expect(sidecar().existsSync(), isFalse);
    });

    // RTF has no way to reference a picture beside the document.
    test('RTF embeds regardless, because the format cannot link out', () async {
      final rtf = await exportTo(NoteExportFormat.rtf);

      expect(rtf, contains(r'\pngblip'));
      expect(rtf, isNot(contains('nota-adjuntos/')));
    });
  });
}
