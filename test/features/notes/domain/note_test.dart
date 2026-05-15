import 'package:flutter_test/flutter_test.dart';
import 'package:notes_app/features/notes/domain/note.dart';
import 'package:notes_app/features/notes/domain/note_attachment.dart';

void main() {
  test('serializes notes with tags and attachments', () {
    final now = DateTime.utc(2026, 5, 14, 12);
    final note = Note(
      id: 'note-1',
      title: 'Security plan',
      body: 'Encrypt local data',
      tags: const ['security'],
      attachments: [
        NoteAttachment(
          id: 'attachment-1',
          originalName: 'plan.pdf',
          vaultName: 'attachment-1.bin.enc',
          sizeBytes: 42,
          createdAt: now,
        ),
      ],
      createdAt: now,
      updatedAt: now,
    );

    final copy = Note.fromJson(note.toJson());

    expect(copy.id, note.id);
    expect(copy.tags, ['security']);
    expect(copy.attachments.single.originalName, 'plan.pdf');
  });
}
