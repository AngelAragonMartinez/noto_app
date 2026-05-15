import 'package:path/path.dart' as p;

class NoteAttachment {
  const NoteAttachment({
    required this.id,
    required this.originalName,
    required this.vaultName,
    required this.sizeBytes,
    required this.createdAt,
    this.mimeType,
  });

  final String id;
  final String originalName;
  final String vaultName;
  final int sizeBytes;
  final DateTime createdAt;
  final String? mimeType;

  String get extension => p.extension(originalName).replaceFirst('.', '');

  NoteAttachment copyWith({
    String? id,
    String? originalName,
    String? vaultName,
    int? sizeBytes,
    DateTime? createdAt,
    String? mimeType,
  }) {
    return NoteAttachment(
      id: id ?? this.id,
      originalName: originalName ?? this.originalName,
      vaultName: vaultName ?? this.vaultName,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      createdAt: createdAt ?? this.createdAt,
      mimeType: mimeType ?? this.mimeType,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'originalName': originalName,
        'vaultName': vaultName,
        'sizeBytes': sizeBytes,
        'createdAt': createdAt.toIso8601String(),
        'mimeType': mimeType,
      };

  factory NoteAttachment.fromJson(Map<String, Object?> json) {
    return NoteAttachment(
      id: json['id'] as String,
      originalName: json['originalName'] as String,
      vaultName: json['vaultName'] as String,
      sizeBytes: json['sizeBytes'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      mimeType: json['mimeType'] as String?,
    );
  }
}
