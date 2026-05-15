import 'package:uuid/uuid.dart';

import '../../../core/storage/vault_data.dart';
import '../../../core/storage/vault_store.dart';
import '../domain/note.dart';
import '../domain/note_attachment.dart';

class NotesRepository {
  NotesRepository({required VaultStore store, Uuid? uuid})
      : _store = store,
        _uuid = uuid ?? const Uuid();

  final VaultStore _store;
  final Uuid _uuid;

  Future<List<Note>> list({bool includeDeleted = false}) async {
    final data = await _store.read();
    final notes = includeDeleted
        ? data.notes
        : data.notes.where((note) => !note.isDeleted).toList();
    notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return notes;
  }

  Future<Note> create({
    String title = 'New note',
    String body = '',
    List<String> tags = const [],
  }) async {
    final now = DateTime.now().toUtc();
    final note = Note(
      id: _uuid.v4(),
      title: title,
      body: body,
      tags: tags,
      createdAt: now,
      updatedAt: now,
    );
    await _mutate((data) => data.copyWith(notes: [note, ...data.notes]));
    return note;
  }

  Future<Note> save(Note note) async {
    final updated = note.copyWith(updatedAt: DateTime.now().toUtc());
    await _mutate((data) {
      return data.copyWith(
        notes: data.notes.map((candidate) {
          return candidate.id == note.id ? updated : candidate;
        }).toList(),
      );
    });
    return updated;
  }

  Future<void> moveToTrash(String noteId) async {
    await _mutateNote(
      noteId,
      (note) => note.copyWith(
        deletedAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> restore(String noteId) async {
    await _mutateNote(
      noteId,
      (note) => note.copyWith(
        clearDeletedAt: true,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> permanentlyDelete(String noteId) async {
    await _mutate((data) {
      return data.copyWith(
        notes: data.notes.where((note) => note.id != noteId).toList(),
      );
    });
  }

  Future<Note> addAttachment(String noteId, NoteAttachment attachment) async {
    late Note updated;
    await _mutateNote(noteId, (note) {
      updated = note.copyWith(
        attachments: [...note.attachments, attachment],
        updatedAt: DateTime.now().toUtc(),
      );
      return updated;
    });
    return updated;
  }

  Future<Note> removeAttachment(String noteId, String attachmentId) async {
    late Note updated;
    await _mutateNote(noteId, (note) {
      updated = note.copyWith(
        attachments: note.attachments
            .where((attachment) => attachment.id != attachmentId)
            .toList(),
        updatedAt: DateTime.now().toUtc(),
      );
      return updated;
    });
    return updated;
  }

  Future<List<Note>> search(String query, {bool includeDeleted = false}) async {
    final normalized = query.trim().toLowerCase();
    final notes = await list(includeDeleted: includeDeleted);
    if (normalized.isEmpty) {
      return notes;
    }
    return notes.where((note) {
      final tags = note.tags.join(' ').toLowerCase();
      return note.title.toLowerCase().contains(normalized) ||
          note.body.toLowerCase().contains(normalized) ||
          tags.contains(normalized);
    }).toList();
  }

  Future<void> _mutate(VaultData Function(VaultData data) update) async {
    final data = await _store.read();
    await _store.write(update(data));
  }

  Future<void> _mutateNote(String noteId, Note Function(Note note) update) async {
    await _mutate((data) {
      return data.copyWith(
        notes: data.notes.map((note) {
          return note.id == noteId ? update(note) : note;
        }).toList(),
      );
    });
  }
}
