import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:notes_app/features/notes/data/note_import.dart';

void main() {
  group('NoteImport', () {
    test('plain text becomes a single Quill body', () {
      final r = NoteImportResult.parse('hello.txt', 'hello\nworld');
      expect(r.title, 'hello');
      expect(r.body, contains('"insert"'));
      expect(r.body, contains('hello\nworld'));
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
