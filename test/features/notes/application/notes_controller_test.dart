import 'dart:io';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_app/app/app_strings.dart';
import 'package:notes_app/core/storage/vault_paths.dart';
import 'package:notes_app/features/documents/data/document_repository.dart';
import 'package:notes_app/features/notes/application/notes_controller.dart';
import 'package:notes_app/features/notes/data/note_export_repository.dart';
import 'package:notes_app/features/notes/data/notes_repository.dart';
import 'package:path/path.dart' as p;

import '../../../fakes/fake_vault_store.dart';

class _TempPaths extends VaultPaths {
  _TempPaths(this.root);

  final Directory root;

  @override
  Future<Directory> appDirectory() async => root;
}

void main() {
  late Directory root;
  late FakeVaultStore store;
  late NotesRepository repository;
  late ProviderContainer container;

  setUp(() {
    root = Directory.systemTemp.createTempSync('noto_controller_test_');
    store = FakeVaultStore();
    repository = NotesRepository(store: store);
    container = ProviderContainer(
      overrides: [
        notesRepositoryProvider.overrideWithValue(repository),
        documentRepositoryProvider.overrideWithValue(
          DocumentRepository(paths: _TempPaths(root)),
        ),
        noteExportRepositoryProvider.overrideWithValue(
          NoteExportRepository(paths: _TempPaths(root)),
        ),
        // Short-circuits LocaleController, which would otherwise reach for the
        // real application support directory while the test runs.
        appStringsProvider.overrideWithValue(AppStrings(const Locale('en'))),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  NotesController controller() =>
      container.read(notesControllerProvider.notifier);

  group('creating a note from Trash', () {
    // Reloading with the trash filter on searched deleted notes only, so the new
    // note was filtered out of its own list: the button looked dead while leaving
    // an orphan in the vault.
    test('leaves Trash and shows the new note', () async {
      await repository.create(title: 'Vieja');
      await controller().load();
      controller().toggleTrash();
      expect(container.read(notesControllerProvider).showTrash, isTrue);

      await controller().createNote();

      final state = container.read(notesControllerProvider);
      expect(state.showTrash, isFalse, reason: 'returns to the notes list');
      expect(state.selectedNoteId, isNotNull);
      expect(
        state.notes.map((n) => n.id),
        contains(state.selectedNoteId),
        reason: 'the note it just created is visible',
      );
    });
  });

  group('saving to a remembered path', () {
    // An unknown stored format name fell back to txt, which wrote plain text
    // into whatever the path was called and reported success.
    test('an unknown format name falls back to the file extension', () async {
      final target = p.join(root.path, 'nota.md');
      var note = await repository.create(title: 'Titulo');
      note = await repository.save(note.copyWith(
        body: r'[{"insert":"Cuerpo\n"}]',
        lastExportPath: target,
        lastExportFormat: 'docx', // never a NoteExportFormat value
      ));
      await controller().load();
      controller().select(note.id);

      await controller().saveSelected();

      final written = File(target).readAsStringSync();
      expect(
        written,
        contains('# Titulo'),
        reason: 'written as Markdown, matching the .md it replaced',
      );
    });
  });

  group('removing a note from Noto', () {
    // The Save dialog used to open inside the app's own exports folder, and the
    // purge deleted anything under app data on the assumption that it was a copy
    // Noto had made. Saving without navigating elsewhere therefore handed the
    // user's file to the next removal. lastExportPath is always a path the user
    // picked, so it is never Noto's to delete, wherever it happens to sit.
    test('leaves the file the user saved, even inside app data', () async {
      final saved = File(p.join(root.path, 'nota.md'))
        ..writeAsStringSync('# Mi nota');
      var note = await repository.create(title: 'Mi nota');
      note = await repository.save(note.copyWith(
        lastExportPath: saved.path,
        lastExportFormat: 'markdown',
      ));
      await controller().load();
      controller().select(note.id);

      await controller().removeSelectedNoteFromApp();

      expect(saved.existsSync(), isTrue, reason: 'the saved file survives');
      expect(await repository.list(), isEmpty, reason: 'the note still leaves');
    });
  });
}
