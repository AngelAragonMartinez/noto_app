import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:path/path.dart' as p;

import '../../../app/app_strings.dart';
import '../../../core/storage/adaptive_vault_store.dart';
import '../../../core/storage/vault_paths.dart';
import '../../documents/data/document_repository.dart';
import '../data/note_import.dart';
import '../data/note_export_repository.dart';
import '../data/notes_repository.dart';
import '../data/user_guide_body_builder.dart';
import '../data/recent_note_imports_store.dart';
import '../domain/note.dart';
import '../domain/note_attachment.dart';
import 'notes_state.dart';

final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  return NotesRepository(store: AdaptiveVaultStore());
});

final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  return DocumentRepository();
});

final recentImportsStoreProvider = Provider<RecentNoteImportsStore>((ref) {
  return RecentNoteImportsStore();
});

final noteExportRepositoryProvider = Provider<NoteExportRepository>((ref) {
  return NoteExportRepository(
    documents: ref.watch(documentRepositoryProvider),
  );
});

final notesControllerProvider =
    StateNotifierProvider<NotesController, NotesState>((ref) {
  return NotesController(
    ref: ref,
    notesRepository: ref.watch(notesRepositoryProvider),
    documentRepository: ref.watch(documentRepositoryProvider),
    exportRepository: ref.watch(noteExportRepositoryProvider),
    recentImports: ref.watch(recentImportsStoreProvider),
  )..load();
});

class NotesController extends StateNotifier<NotesState> {
  NotesController({
    required this._ref,
    required this._notesRepository,
    required this._documentRepository,
    required this._exportRepository,
    required this._recentImports,
  }) : super(const NotesState(isLoading: true));

  final Ref _ref;
  final NotesRepository _notesRepository;
  final DocumentRepository _documentRepository;
  final NoteExportRepository _exportRepository;
  final RecentNoteImportsStore _recentImports;
  Timer? _infoTimer;
  final Map<String, Note> _baselineNotes = {};

  void _rebuildBaselinesFromNotes(List<Note> notes) {
    final ids = notes.map((n) => n.id).toSet();
    _baselineNotes.removeWhere((id, _) => !ids.contains(id));
    for (final n in notes) {
      _baselineNotes[n.id] = n;
    }
  }

  void _recordBaseline(Note note) {
    _baselineNotes[note.id] = note;
  }

  bool _tagsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    return a.toSet().containsAll(b);
  }

  bool isNoteDirty(Note note) {
    final b = _baselineNotes[note.id];
    if (b == null) return false;
    if (note.title != b.title || note.body != b.body) return true;
    if (!_tagsEqual(note.tags, b.tags)) return true;
    final sa = note.attachments.map((a) => a.id).toSet();
    final sb = b.attachments.map((a) => a.id).toSet();
    return sa.length != sb.length || !sa.containsAll(sb);
  }

  void clearInfo() {
    _infoTimer?.cancel();
    _infoTimer = null;
    state = state.copyWith(clearInfo: true);
  }

  void _flashInfo(String message) {
    state = state.copyWith(info: message);
    _infoTimer?.cancel();
    _infoTimer = Timer(const Duration(milliseconds: 2600), () {
      if (!mounted) return;
      state = state.copyWith(clearInfo: true);
    });
  }

  /// Shows [message] in the info bar until something clears it.
  ///
  /// Unlike [_flashInfo] there is no timer: a path is there to be read and
  /// copied down, which is slower than the couple of seconds a save
  /// confirmation needs.
  void showPinnedInfo(String message) {
    _infoTimer?.cancel();
    _infoTimer = null;
    state = state.copyWith(info: message);
  }

  /// Where the open note lives, ready to show to the user.
  ///
  /// The file it was last exported to, when there is one — that is the copy
  /// people go looking for. Otherwise the folder holding the vault, since a
  /// note that has never been exported has no file of its own.
  Future<String> currentNoteLocation() async {
    final exported = state.selectedNote?.lastExportPath;
    if (exported != null && exported.trim().isNotEmpty) {
      return exported;
    }
    return _exportRepository.storagePath();
  }

  Future<void> load() async {
    await _guard(() async {
      final notes = await _notesRepository.search(
        state.query,
        onlyDeleted: state.showTrash,
      );
      final selectedNoteId = () {
        if (notes.isEmpty) {
          return null;
        }
        if (state.selectedNoteId != null &&
            notes.any((n) => n.id == state.selectedNoteId)) {
          return state.selectedNoteId;
        }
        if (state.userClearedSelection) {
          return null;
        }
        return notes.first.id;
      }();

      final keepUserCleared = selectedNoteId == null &&
          notes.isNotEmpty &&
          state.userClearedSelection;

      _rebuildBaselinesFromNotes(notes);
      state = state.copyWith(
        notes: notes,
        selectedNoteId: selectedNoteId,
        clearSelectedNote: selectedNoteId == null,
        userClearedSelection: keepUserCleared,
        isLoading: false,
        clearError: true,
        clearInfo: true,
      );
    });
    await ensureUserGuideNoteIfNeeded();
  }

  Future<void> ensureUserGuideNoteIfNeeded() async {
    try {
      final s = _ref.read(appStringsProvider);
      final title = s.userGuideNoteTitle;
      final bodyDelta = buildUserGuideNoteBodyDeltaJson(s);
      final legacyTitles = {
        s.userGuideNoteTitle.trim(),
        s.userGuideLegacyTitleEn.trim(),
        s.userGuideLegacyTitleEs.trim(),
      };

      final dir = await const VaultPaths().appDirectory();
      final marker = File(p.join(dir.path, '.noto_user_guide'));

      var notes = await _notesRepository.search(
        state.query,
        onlyDeleted: state.showTrash,
      );
      var markerDone = false;
      if (await marker.exists()) {
        try {
          markerDone = (await marker.readAsString()).trim() == 'v2';
        } catch (_) {
          markerDone = false;
        }
      }
      if (markerDone) {
        return;
      }

      Note? existing;
      for (final n in notes) {
        if (legacyTitles.contains(n.title.trim())) {
          existing = n;
          break;
        }
      }

      final oldMarker = File(p.join(dir.path, '.user_guide_seeded'));

      late final Note guideNote;
      if (existing != null) {
        final tags = existing.tags.contains('noto')
            ? existing.tags
            : [...existing.tags, 'noto'];
        final needsUpdate = existing.title.trim() != title.trim() ||
            existing.body != bodyDelta ||
            !_tagsEqual(existing.tags, tags);
        guideNote = needsUpdate
            ? await _notesRepository.save(
                existing.copyWith(
                  title: title,
                  body: bodyDelta,
                  tags: tags,
                ),
              )
            : existing;
      } else {
        guideNote = await _notesRepository.create(
          title: title,
          body: bodyDelta,
          tags: const ['noto'],
        );
      }

      await marker.writeAsString('v2');
      if (await oldMarker.exists()) {
        await oldMarker.delete();
      }

      _recordBaseline(guideNote);
      if (!mounted) return;
      notes = await _notesRepository.search(
        state.query,
        onlyDeleted: state.showTrash,
      );
      _rebuildBaselinesFromNotes(notes);
      final keepId = state.selectedNoteId;
      final nextSelected = keepId != null && notes.any((n) => n.id == keepId)
          ? keepId
          : (notes.isEmpty ? null : notes.first.id);
      state = state.copyWith(
        notes: notes,
        selectedNoteId: nextSelected,
        clearSelectedNote: nextSelected == null,
        userClearedSelection: nextSelected != null
            ? false
            : state.userClearedSelection,
      );
    } catch (_) {}
  }

  Future<void> createNote() async {
    await _guard(() async {
      final note = await _notesRepository.create(
        title: _ref.read(appStringsProvider).newNote,
      );
      _recordBaseline(note);
      // Creating a note implies wanting to see it. Reloading with the trash
      // filter still on asked for deleted notes only, so a note created from
      // Trash was filtered straight out of its own list: the button looked dead
      // while quietly leaving orphans in the vault, every one of them carrying
      // the same default title.
      final notes = await _notesRepository.search(
        state.query,
        onlyDeleted: false,
      );
      _rebuildBaselinesFromNotes(notes);
      state = state.copyWith(
        notes: notes,
        selectedNoteId: note.id,
        showTrash: false,
        clearError: true,
        userClearedSelection: false,
      );
    });
  }

  void select(String noteId) {
    state = state.copyWith(
      selectedNoteId: noteId,
      userClearedSelection: false,
    );
  }

  void clearSelection() {
    state = state.copyWith(
      clearSelectedNote: true,
      userClearedSelection: true,
    );
  }
  
  Future<void> flushSave(Note note) async {
    final latest = state.notes.firstWhere(
      (n) => n.id == note.id,
      orElse: () => note,
    );
    final saved = await _notesRepository.save(latest);
    if (!mounted) return;
    _recordBaseline(saved);
    state = state.copyWith(
      notes: state.notes
          .map((candidate) => candidate.id == saved.id ? saved : candidate)
          .toList(),
    );
  }

  bool _isTrivialBlankDraft(Note note) {
    if (note.attachments.isNotEmpty) return false;
    const blankTitles = {'New note', 'Nota nueva'};
    if (!blankTitles.contains(note.title.trim())) return false;
    return note.body.isEmpty;
  }
  
  Future<void> revertToBaseline(Note note) async {
    final b = _baselineNotes[note.id];
    if (b == null) {
      await load();
      return;
    }
    if (_isTrivialBlankDraft(b)) {
      await _notesRepository.permanentlyDelete(note.id);
      _baselineNotes.remove(note.id);
      if (state.selectedNoteId == note.id) {
        clearSelection();
      }
      await load();
      return;
    }
    final restored = await _notesRepository.save(b);
    if (!mounted) return;
    _recordBaseline(restored);
    state = state.copyWith(
      notes: state.notes
          .map((candidate) => candidate.id == restored.id ? restored : candidate)
          .toList(),
    );
  }

  void setQuery(String query) {
    state = state.copyWith(query: query);
    unawaited(load());
  }

  void toggleTrash() {
    state = state.copyWith(
      showTrash: !state.showTrash,
      clearSelectedNote: true,
      userClearedSelection: false,
    );
    unawaited(load());
  }

  void updateDraft(Note note, {String? title, String? body, List<String>? tags}) {
    final updated = note.copyWith(title: title, body: body, tags: tags);
    state = state.copyWith(
      notes: state.notes.map((candidate) {
        return candidate.id == note.id ? updated : candidate;
      }).toList(),
      selectedNoteId: note.id,
      userClearedSelection: false,
    );
  }

  Future<void> importNoteFromFile() async {
    final file = await _documentRepository.pickNoteImportFile(
      importLabel: _ref.read(appStringsProvider).fileFilterImport,
    );
    if (file == null) {
      return;
    }
    await _importFromXFile(file);
  }

  Future<void> importNoteFromPath(String path) async {
    final f = File(path);
    if (!await f.exists()) {
      await _recentImports.remove(path);
      _flashInfo(_ref.read(appStringsProvider).fileMissingRecents);
      return;
    }
    await _importFromXFile(XFile(path));
  }

  Future<void> _importFromXFile(XFile file) async {
    await _guard(() async {
      final raw = await file.readAsString();
      final parsed = NoteImportResult.parse(file.name, raw);
      var note = await _notesRepository.create(
        title: parsed.title,
        body: parsed.body,
        tags: parsed.tags,
      );
      if (file.path.isNotEmpty) {
        final ext = p.extension(file.name).replaceFirst('.', '').toLowerCase();
        final format = NoteExportFormat.fromExtension(ext);
        if (format != null) {
          note = await _notesRepository.save(note.copyWith(
            lastExportPath: file.path,
            lastExportFormat: format.name,
          ));
        }
      }
      _recordBaseline(note);
      if (file.path.isNotEmpty) {
        await _recentImports.prepend(file.path);
      }
      final notes = await _notesRepository.search(
        state.query,
        onlyDeleted: state.showTrash,
      );
      _rebuildBaselinesFromNotes(notes);
      state = state.copyWith(
        notes: notes,
        selectedNoteId: note.id,
        clearError: true,
        userClearedSelection: false,
      );
      _flashInfo(_ref.read(appStringsProvider).openedFile(file.name));
    });
  }

  Future<void> moveSelectedToTrash() async {
    final note = state.selectedNote;
    if (note == null) {
      return;
    }
    await _guard(() async {
      await _notesRepository.moveToTrash(note.id);
      state = state.copyWith(clearSelectedNote: true);
      await load();
    });
  }

  Future<void> restoreSelected() async {
    final note = state.selectedNote;
    if (note == null) {
      return;
    }
    await _guard(() async {
      await _notesRepository.restore(note.id);
      await load();
    });
  }

  Future<void> permanentlyDeleteSelected() async {
    final note = state.selectedNote;
    if (note == null) {
      return;
    }
    await _guard(() async {
      await _purgeNoteFromDisk(note);
      await _notesRepository.permanentlyDelete(note.id);
      state = state.copyWith(clearSelectedNote: true);
      await load();
    });
  }

  Future<void> _purgeNoteFromDisk(Note note) async {
    for (final attachment in note.attachments) {
      try {
        await _documentRepository.deleteVaultFile(attachment.vaultName);
      } catch (_) {}
    }
    // lastExportPath is never Noto's own copy: it is set from the path the user
    // picked in the Save dialog, or the file they imported. This used to be run
    // through a helper that deleted it whenever it happened to sit under app
    // data, and the Save dialog opened inside app data by default, so saving
    // without navigating elsewhere put the user's file in a folder Noto later
    // emptied. Provenance is not location; a file the user chose a place for is
    // never ours to delete.
    await _documentRepository.deleteInlineImagesFromQuillBody(note.body);
  }

  /// Drop note from Noto (not Trash): removes vault copy and list entry.
  ///
  /// Only Noto's own copies go: [DocumentRepository.tryDeleteUnderAppData]
  /// refuses any path outside app data, so a note you also keep as a file of
  /// your own survives this untouched. That is the point of the action.
  Future<void> removeSelectedNoteFromApp() async {
    final note = state.selectedNote;
    if (note == null) {
      return;
    }
    await _guard(() async {
      await _purgeNoteFromDisk(note);
      await _notesRepository.permanentlyDelete(note.id);
      state = state.copyWith(clearSelectedNote: true);
      await load();
    });
  }

  Future<void> openAttachment(NoteAttachment attachment) async {
    await _guard(() async {
      await _documentRepository.openAttachment(attachment);
    });
  }

  Future<void> removeAttachment(NoteAttachment attachment) async {
    final note = state.selectedNote;
    if (note == null) {
      return;
    }
    await _guard(() async {
      await _notesRepository.removeAttachment(note.id, attachment.id);
      try {
        await _documentRepository.deleteVaultFile(attachment.vaultName);
      } catch (_) {}
      await load();
      _flashInfo(
        _ref.read(appStringsProvider).attachmentRemoved(attachment.originalName),
      );
    });
  }

  Future<void> attachDocument() async {
    final note = state.selectedNote;
    if (note == null) {
      return;
    }
    await _guard(() async {
      final attachment = await _documentRepository.pickAndStore(
        documentsLabel: _ref.read(appStringsProvider).fileFilterDocuments,
      );
      if (attachment == null) {
        return;
      }
      await _notesRepository.addAttachment(note.id, attachment);
      await load();
      _flashInfo(
        _ref.read(appStringsProvider).attachmentSaved(attachment.originalName),
      );
    });
  }

  Future<void> exportSelected({NoteExportFormat? preferredFormat}) async {
    final note = state.selectedNote;
    if (note == null) {
      return;
    }
    await _guard(() async {
      try {
        final latest = state.notes.firstWhere(
          (n) => n.id == note.id,
          orElse: () => note,
        );
        await flushSave(latest);
        final toExport = state.notes.firstWhere(
          (n) => n.id == note.id,
          orElse: () => latest,
        );
        final result = await _exportRepository.export(
          toExport,
          preferredFormat: preferredFormat,
          strings: _ref.read(appStringsProvider),
        );
        await _rememberLastExport(toExport, result);
        _flashInfo(
          _ref.read(appStringsProvider).savedToPath(result.file.path),
        );
      } on ExportCancelledException {
        clearInfo();
      }
    });
  }

  Future<void> saveSelected() async {
    final note = state.selectedNote;
    if (note == null) return;
    final path = note.lastExportPath;
    final formatName = note.lastExportFormat;
    if (path == null || formatName == null) {
      await exportSelected();
      return;
    }
    // A stored format name that matches nothing used to fall back to txt, which
    // then wrote plain text into whatever the path was called: a .pdf or .md
    // silently replaced by its own text contents, reported as a successful save.
    // Recover the format from the file's extension instead, and when that is
    // unknown too, ask through the export dialog rather than guess.
    NoteExportFormat? resolved;
    for (final candidate in NoteExportFormat.values) {
      if (candidate.name == formatName) {
        resolved = candidate;
        break;
      }
    }
    resolved ??= NoteExportFormat.fromExtension(
      p.extension(path).replaceFirst('.', '').toLowerCase(),
    );
    if (resolved == null) {
      await exportSelected();
      return;
    }
    final format = resolved;
    await _guard(() async {
      final latest = state.notes.firstWhere(
        (n) => n.id == note.id,
        orElse: () => note,
      );
      await flushSave(latest);
      final current = state.notes.firstWhere(
        (n) => n.id == note.id,
        orElse: () => latest,
      );
      final result = await _exportRepository.saveAt(
        current,
        path,
        format,
        strings: _ref.read(appStringsProvider),
      );
      await _rememberLastExport(current, result);
      _flashInfo(
        _ref.read(appStringsProvider).savedToPath(result.file.path),
      );
    });
  }

  Future<void> _rememberLastExport(Note note, NoteExportResult result) async {
    final latest = state.notes.firstWhere(
      (n) => n.id == note.id,
      orElse: () => note,
    );
    final updated = latest.copyWith(
      lastExportPath: result.file.path,
      lastExportFormat: result.format.name,
    );
    await _notesRepository.save(updated);
    await load();
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      state = state.copyWith(isLoading: true, clearError: true, clearInfo: true);
      await action();
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    } finally {
      if (mounted) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  @override
  void dispose() {
    _infoTimer?.cancel();
    super.dispose();
  }
}
