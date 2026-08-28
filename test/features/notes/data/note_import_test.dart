import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:notes_app/features/notes/data/note_import.dart';

void main() {
  _htmlImportTests();
  group('NoteImport', () {
    test('plain text becomes a single Quill body', () {
      final r = NoteImportResult.parse('hello.txt', 'hello\nworld');
      expect(r.title, 'hello');
      final delta = jsonDecode(r.body) as List;
      expect(delta, isNotEmpty);
      final firstOp = delta.first as Map;
      expect(firstOp['insert'], contains('hello\nworld'));
      expect(r.tags, isEmpty);
    });

    test('JSON array is accepted as Quill delta', () {
      final raw = jsonEncode([
        {'insert': 'hi\n'},
      ]);
      final r = NoteImportResult.parse('x.json', raw);
      expect(r.title, 'x');
      expect(jsonDecode(r.body), isA<List>());
    });

    test('strips Noto txt export header so re-saving is idempotent', () {
      const exported = 'My note\n=======\n\nHello\nworld\n';
      final r = NoteImportResult.parse('My note.txt', exported);
      expect(r.title, 'My note');
      final delta = jsonDecode(r.body) as List;
      final text = delta
          .whereType<Map>()
          .map((op) => op['insert'])
          .whereType<String>()
          .join();
      expect(text.trim(), 'Hello\nworld');
    });

    test('strips Markdown H1 title header', () {
      const exported = '# My note\n\nHello\n';
      final r = NoteImportResult.parse('My note.md', exported);
      expect(r.title, 'My note');
      final delta = jsonDecode(r.body) as List;
      final text = delta
          .whereType<Map>()
          .map((op) => op['insert'])
          .whereType<String>()
          .join();
      expect(text.trim(), 'Hello');
    });

    test('Noto-style export object picks title, tags, body', () {
      final raw = jsonEncode({
        'title': 'My title',
        'tags': ['a', 'b'],
        'body': [
          {'insert': 'body\n'},
        ],
      });
      final r = NoteImportResult.parse('ignored.json', raw);
      expect(r.title, 'My title');
      expect(r.tags, ['a', 'b']);
      expect(jsonDecode(r.body), isA<List>());
    });
  });
}

void _htmlImportTests() {
  group('HTML import', () {
    String bodyTextOf(NoteImportResult r) {
      final ops = jsonDecode(r.body) as List;
      return ops
          .whereType<Map>()
          .map((op) => op['insert'])
          .whereType<String>()
          .join();
    }

    test('strips markup instead of importing it as literal text', () {
      final result = NoteImportResult.parse(
        'page.html',
        '<html><body><p>Primera</p><p>Segunda</p></body></html>',
      );

      final text = bodyTextOf(result);
      expect(text, isNot(contains('<p>')));
      expect(text, contains('Primera'));
      expect(text, contains('Segunda'));
    });

    test('uses <title> as the note title', () {
      final result = NoteImportResult.parse(
        'page.html',
        '<html><head><title>Notas de la reuni&oacute;n</title></head>'
        '<body><p>Cuerpo</p></body></html>',
      );

      expect(result.title, isNot('page'));
      expect(result.title, contains('Notas de la reuni'));
    });

    test('drops script and style contents', () {
      final result = NoteImportResult.parse(
        'page.html',
        '<html><head><style>body{color:red}</style></head>'
        '<body><script>alert(1)</script><p>Visible</p></body></html>',
      );

      final text = bodyTextOf(result);
      expect(text, contains('Visible'));
      expect(text, isNot(contains('alert')));
      expect(text, isNot(contains('color:red')));
    });

    test('decodes entities, with the ampersand resolved last', () {
      final result = NoteImportResult.parse(
        'page.html',
        '<p>Uno &amp; dos &lt;tres&gt; &#191;cuatro? &#xE9;</p>',
      );

      final text = bodyTextOf(result);
      expect(text, contains('Uno & dos <tres>'));
      expect(text, contains('¿cuatro?'));
      expect(text, contains('é'));
    });

    test('does not double-decode an escaped entity', () {
      final result = NoteImportResult.parse('page.html', '<p>&amp;lt;</p>');

      expect(bodyTextOf(result), contains('&lt;'));
    });

    test('turns <br> and block ends into line breaks', () {
      final result = NoteImportResult.parse(
        'page.html',
        '<p>Uno<br>Dos</p><p>Tres</p>',
      );

      final text = bodyTextOf(result);
      expect(text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty),
          containsAllInOrder(['Uno', 'Dos', 'Tres']));
    });
  });
}
