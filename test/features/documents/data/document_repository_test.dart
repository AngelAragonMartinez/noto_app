import 'package:flutter_test/flutter_test.dart';
import 'package:notes_app/features/documents/data/document_repository.dart';

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
}
