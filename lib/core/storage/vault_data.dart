import '../../features/notes/domain/note.dart';

class VaultData {
  const VaultData({this.notes = const []});

  final List<Note> notes;

  VaultData copyWith({List<Note>? notes}) {
    return VaultData(notes: notes ?? this.notes);
  }

  Map<String, Object?> toJson() => {
        'version': 1,
        'notes': notes.map((note) => note.toJson()).toList(),
      };

  factory VaultData.fromJson(Map<String, Object?> json) {
    return VaultData(
      notes: (json['notes'] as List<Object?>? ?? const [])
          .whereType<Map>()
          .map((note) => Note.fromJson(Map<String, Object?>.from(note)))
          .toList(),
    );
  }
}
