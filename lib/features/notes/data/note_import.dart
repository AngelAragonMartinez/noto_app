import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart';
import 'package:path/path.dart' as p;

/// Result of reading a file Noto can turn into a new note body (Quill JSON).
class NoteImportResult {
  const NoteImportResult({
    required this.title,
    required this.body,
    this.tags = const [],
  });

  final String title;
  final String body;
  final List<String> tags;

  /// [fileName] is used for extension and default title; [utf8Text] is raw file bytes as UTF-8.
  static NoteImportResult parse(String fileName, String utf8Text) {
    final ext = p.extension(fileName).toLowerCase();
    final fallbackTitle = _titleFromFileName(fileName);

    if (ext == '.json') {
      final decoded = jsonDecode(utf8Text);

      if (decoded is List) {
        Document.fromJson(decoded);
        return NoteImportResult(title: fallbackTitle, body: jsonEncode(decoded));
      }

      if (decoded is Map) {
        final map = Map<String, dynamic>.from(decoded);
        final bodyRaw = map['body'];
        if (bodyRaw is List) {
          Document.fromJson(bodyRaw);
          final titleRaw = map['title'] as String?;
          final title = titleRaw?.trim();
          final tagsList = map['tags'];
          final tags = tagsList is List
              ? tagsList
                  .map((e) => e?.toString() ?? '')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList()
              : const <String>[];
          return NoteImportResult(
            title: (title != null && title.isNotEmpty) ? title : fallbackTitle,
            body: jsonEncode(bodyRaw),
            tags: tags,
          );
        }
      }

      throw const FormatException(
        'Expected a Quill delta JSON array or a Noto export object with a "body" array.',
      );
    }

    var title = fallbackTitle;
    var body = utf8Text;

    if (ext == '.txt') {
      final m = RegExp(r'^([^\n]+)\n(=+)\n\n').firstMatch(body);
      if (m != null && m.group(1)!.length == m.group(2)!.length) {
        title = m.group(1)!;
        body = body.substring(m.end);
      }
    } else if (ext == '.md') {
      final m = RegExp(r'^# ([^\n]+)\n\n').firstMatch(body);
      if (m != null) {
        title = m.group(1)!.trim();
        body = body.substring(m.end);
      }
    }

    body = body.replaceAll(RegExp(r'\s+$'), '');

    final doc = Document();
    if (body.isNotEmpty) {
      doc.insert(0, body);
    }
    return NoteImportResult(
      title: title,
      body: jsonEncode(doc.toDelta().toJson()),
    );
  }

  static String _titleFromFileName(String name) {
    final base = p.basenameWithoutExtension(name).trim();
    if (base.isEmpty) return 'Imported note';
    return base;
  }
}
