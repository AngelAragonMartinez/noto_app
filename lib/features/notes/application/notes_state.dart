import '../domain/note.dart';

class NotesState {
  const NotesState({
    this.notes = const [],
    this.query = '',
    this.selectedNoteId,
    this.userClearedSelection = false,
    this.showTrash = false,
    this.isLoading = false,
    this.error,
    this.info,
  });

  final List<Note> notes;
  final String query;
  final String? selectedNoteId;
  /// When true, [load] keeps [selectedNoteId] null instead of defaulting to the first note.
  final bool userClearedSelection;
  final bool showTrash;
  final bool isLoading;
  final String? error;
  final String? info;

  Note? get selectedNote {
    if (selectedNoteId == null) {
      return null;
    }
    for (final note in notes) {
      if (note.id == selectedNoteId) {
        return note;
      }
    }
    return null;
  }

  NotesState copyWith({
    List<Note>? notes,
    String? query,
    String? selectedNoteId,
    bool? userClearedSelection,
    bool? showTrash,
    bool? isLoading,
    String? error,
    String? info,
    bool clearSelectedNote = false,
    bool clearError = false,
    bool clearInfo = false,
  }) {
    final nextSelected = clearSelectedNote ? null : selectedNoteId ?? this.selectedNoteId;
    return NotesState(
      notes: notes ?? this.notes,
      query: query ?? this.query,
      selectedNoteId: nextSelected,
      userClearedSelection: userClearedSelection ?? this.userClearedSelection,
      showTrash: showTrash ?? this.showTrash,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
      info: clearInfo ? null : info ?? this.info,
    );
  }
}
