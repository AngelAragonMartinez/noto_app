import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:notes_app/core/storage/vault_paths.dart';
import 'package:notes_app/features/documents/data/document_repository.dart';
import 'package:path/path.dart' as p;

class _TempPaths extends VaultPaths {
  _TempPaths(this.root);

  final Directory root;

  @override
  Future<Directory> appDirectory() async => root;
}

void main() {
  group('DocumentRepository.safeFileName', () {
    String sanitize(String name) =>
        DocumentRepository.safeFileName(name, fallback: 'fallback.bin');

    test('keeps ordinary names untouched', () {
      expect(sanitize('quarterly-report (final).pdf'),
          'quarterly-report (final).pdf');
    });

    test('keeps accented Latin letters', () {
      expect(sanitize('informe-añó.pdf'), 'informe-añó.pdf');
    });

    test('strips cmd metacharacters that allowed command execution', () {
      // "invoice&calc&.pdf" reached `cmd /c start` unescaped and ran calc.
      final result = sanitize('invoice&calc&.pdf');
      expect(result, isNot(contains('&')));
      for (final meta in [r'&', r'^', r'%', r'!', r'|', r'>', r'<', r'"']) {
        expect(sanitize('a${meta}b.pdf'), isNot(contains(meta)));
      }
    });

    test('strips path separators so the name cannot escape its directory', () {
      expect(sanitize(r'..\..\Windows\System32\evil.dll'), 'evil.dll');
      expect(sanitize('../../etc/passwd'), 'passwd');
    });

    test('falls back when nothing usable remains', () {
      expect(sanitize('...'), 'fallback.bin');
      expect(sanitize(''), 'fallback.bin');
      expect(sanitize('   '), 'fallback.bin');
    });

    test('escapes Windows reserved device names', () {
      expect(sanitize('CON'), '_CON');
      expect(sanitize('nul.txt'), '_nul.txt');
      expect(sanitize('LPT9.pdf'), '_LPT9.pdf');
    });

    test('does not leave a leading dot or trailing dot/space', () {
      expect(sanitize('.hidden.pdf'), 'hidden.pdf');
      expect(sanitize('report.pdf   '), 'report.pdf');
      expect(sanitize('report.pdf...'), 'report.pdf');
    });

    test('caps the length while keeping the extension', () {
      final long = '${'a' * 400}.pdf';
      final result = sanitize(long);
      expect(result.length, lessThanOrEqualTo(120));
      expect(result, endsWith('.pdf'));
    });
  });

  group('tryDeleteUnderAppData stays inside app data', () {
    late Directory appData;
    late Directory elsewhere;

    setUp(() {
      appData = Directory.systemTemp.createTempSync('noto_appdata_');
      elsewhere = Directory.systemTemp.createTempSync('noto_downloads_');
    });

    tearDown(() {
      for (final d in [appData, elsewhere]) {
        if (d.existsSync()) d.deleteSync(recursive: true);
      }
    });

    DocumentRepository repo() => DocumentRepository(paths: _TempPaths(appData));

    // Dropping a note from Noto runs this over the note's export path. A user
    // reported the file they had saved to their Downloads folder disappearing
    // with the note, which this boundary is supposed to make impossible.
    test('leaves a file the user saved outside Noto', () async {
      final saved = File(p.join(elsewhere.path, 'nota.md'))
        ..writeAsStringSync('# Mi nota');

      await repo().tryDeleteUnderAppData(saved.path);

      expect(saved.existsSync(), isTrue, reason: saved.path);
    });

    test('leaves a sibling directory that merely shares a prefix', () async {
      final sibling = Directory('${appData.path}-otro')..createSync();
      final saved = File(p.join(sibling.path, 'nota.md'))
        ..writeAsStringSync('# Mi nota');

      await repo().tryDeleteUnderAppData(saved.path);

      expect(saved.existsSync(), isTrue);
      sibling.deleteSync(recursive: true);
    });

    test('still deletes Noto own copies inside app data', () async {
      final managed = File(p.join(appData.path, 'copia.md'))
        ..writeAsStringSync('# Copia');

      await repo().tryDeleteUnderAppData(managed.path);

      expect(managed.existsSync(), isFalse);
    });
  });
}
