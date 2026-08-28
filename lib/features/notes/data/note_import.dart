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
    } else if (ext == '.html' || ext == '.htm') {
      final htmlTitle = _htmlTitle(body);
      if (htmlTitle.isNotEmpty) title = htmlTitle;
      body = _htmlToText(body);
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

  /// The document's `<title>`, which names a note better than its file name.
  static String _htmlTitle(String html) {
    final match = RegExp(
      r'<title[^>]*>(.*?)</title>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);
    if (match == null) return '';
    return _decodeHtmlEntities(match.group(1)!).trim().replaceAll(
          RegExp(r'\s+'),
          ' ',
        );
  }

  /// Flattens HTML to readable text.
  ///
  /// Noto stores bodies as Quill deltas and has no HTML parser, so imported
  /// markup previously landed in the note as literal `<p>` tags. This keeps
  /// the prose and the line breaks and drops everything else — no formatting
  /// is carried over.
  static String _htmlToText(String html) {
    var text = html;
    // Script and style bodies are code, not prose.
    text = text.replaceAll(
      RegExp(
        r'<(script|style)[^>]*>.*?</\1\s*>',
        caseSensitive: false,
        dotAll: true,
      ),
      '',
    );
    text = text.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
    // Turn block boundaries into line breaks before the tags disappear.
    text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    text = text.replaceAll(
      RegExp(
        r'</(p|div|li|tr|h[1-6]|blockquote|pre|section|article)\s*>',
        caseSensitive: false,
      ),
      '\n',
    );
    text = text.replaceAll(RegExp(r'<[^>]*>'), '');
    text = _decodeHtmlEntities(text);
    // Stripping tags leaves ragged whitespace behind.
    text = text.replaceAll(RegExp(r'[ \t]+\n'), '\n');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }

  static const _namedHtmlEntities = {
    '&lt;': '<',
    '&gt;': '>',
    '&quot;': '"',
    '&apos;': "'",
    '&#39;': "'",
    '&nbsp;': ' ',
    '&hellip;': '…',
    '&mdash;': '—',
    '&ndash;': '–',
    '&laquo;': '«',
    '&raquo;': '»',
  };

  static String _decodeHtmlEntities(String value) {
    var out = value;
    _namedHtmlEntities.forEach((entity, char) {
      out = out.replaceAll(entity, char);
    });
    out = out.replaceAllMapped(
      RegExp(r'&#(\d{1,7});'),
      (m) => _codePoint(int.tryParse(m.group(1)!), m[0]!),
    );
    out = out.replaceAllMapped(
      RegExp(r'&#[xX]([0-9a-fA-F]{1,6});'),
      (m) => _codePoint(int.tryParse(m.group(1)!, radix: 16), m[0]!),
    );
    // Ampersand last, so "&amp;lt;" decodes to "&lt;" rather than to "<".
    return out.replaceAll('&amp;', '&');
  }

  static String _codePoint(int? value, String original) {
    if (value == null || value < 0 || value > 0x10FFFF) return original;
    return String.fromCharCode(value);
  }

  static String _titleFromFileName(String name) {
    final base = p.basenameWithoutExtension(name).trim();
    if (base.isEmpty) return 'Imported note';
    return base;
  }
}
