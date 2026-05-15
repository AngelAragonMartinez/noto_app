import 'dart:convert';

import 'note_attachment.dart';

class Note {
  Note({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
    this.tags = const [],
    this.attachments = const [],
    this.deletedAt,
    this.lastExportPath,
    this.lastExportFormat,
  });

  final String id;
  final String title;
  final String body;
  final List<String> tags;
  final List<NoteAttachment> attachments;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String? lastExportPath;
  final String? lastExportFormat;

  // Lazy cache: each Note instance is replaced on save, so this stays cheap.
  String? _cachedPlainText;
  String? _cachedPreview;

  bool get isDeleted => deletedAt != null;

  String get bodyPlainText {
    if (_cachedPlainText != null) return _cachedPlainText!;
    if (body.isEmpty) {
      _cachedPlainText = '';
      return '';
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is List) {
        _cachedPlainText = decoded
            .whereType<Map>()
            .map((op) => op['insert'])
            .whereType<String>()
            .join();
        return _cachedPlainText!;
      }
    } catch (_) {}
    _cachedPlainText = body;
    return body;
  }

  String get preview {
    if (_cachedPreview != null) return _cachedPreview!;
    final text = bodyPlainText.trim().replaceAll(RegExp(r'\s+'), ' ');
    _cachedPreview = text.isEmpty
        ? 'Empty'
        : (text.length <= 120 ? text : '${text.substring(0, 120)}...');
    return _cachedPreview!;
  }

  Note copyWith({
    String? id,
    String? title,
    String? body,
    List<String>? tags,
    List<NoteAttachment>? attachments,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    String? lastExportPath,
    String? lastExportFormat,
    bool clearDeletedAt = false,
    bool clearLastExport = false,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      tags: tags ?? this.tags,
      attachments: attachments ?? this.attachments,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : deletedAt ?? this.deletedAt,
      lastExportPath:
          clearLastExport ? null : lastExportPath ?? this.lastExportPath,
      lastExportFormat:
          clearLastExport ? null : lastExportFormat ?? this.lastExportFormat,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'tags': tags,
        'attachments': attachments.map((attachment) => attachment.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'deletedAt': deletedAt?.toIso8601String(),
        'lastExportPath': lastExportPath,
        'lastExportFormat': lastExportFormat,
      };

  factory Note.fromJson(Map<String, Object?> json) {
    return Note(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      tags: (json['tags'] as List<Object?>? ?? const [])
          .whereType<String>()
          .toList(),
      attachments: (json['attachments'] as List<Object?>? ?? const [])
          .whereType<Map>()
          .map(
            (attachment) => NoteAttachment.fromJson(
              Map<String, Object?>.from(attachment),
            ),
          )
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      deletedAt: json['deletedAt'] == null
          ? null
          : DateTime.parse(json['deletedAt'] as String),
      lastExportPath: json['lastExportPath'] as String?,
      lastExportFormat: json['lastExportFormat'] as String?,
    );
  }
}
