import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';

import '../../../app/app_strings.dart';
import '../../../core/storage/vault_paths.dart';
import '../../documents/data/document_repository.dart';
import '../domain/note.dart';
import '../domain/note_attachment.dart';

enum NoteExportFormat {
  txt('Plain text', 'txt'),
  markdown('Markdown', 'md'),
  rtf('RTF (Word / LibreOffice)', 'rtf'),
  pdf('PDF', 'pdf'),
  html('HTML', 'html'),
  json('JSON', 'json');

  const NoteExportFormat(this.label, this.extension);

  final String label;
  final String extension;

  static NoteExportFormat? fromExtension(String? ext) {
    if (ext == null) return null;
    final normalized = ext.toLowerCase();
    for (final format in values) {
      if (format.extension == normalized) return format;
    }
    return null;
  }
}

/// The file types the save dialog offers.
///
/// One type when a format was asked for by name, every type otherwise. The two
/// were briefly conflated with the remembered default, which narrowed the
/// dialog to whatever the note was saved as last time: save once as text and
/// text was the only thing ever offered again.
List<XTypeGroup> exportTypeGroups(
  NoteExportFormat? preferredFormat,
  AppStrings strings,
) {
  final offered = preferredFormat != null
      ? [preferredFormat]
      : NoteExportFormat.values;
  return [
    for (final format in offered)
      XTypeGroup(
        label: strings.exportFormatLabel(format),
        extensions: [format.extension],
      ),
  ];
}


class NoteExportRepository {
  NoteExportRepository({
    VaultPaths? paths,
    this._documents,
  }) : _paths = paths ?? const VaultPaths();

  final VaultPaths _paths;
  final DocumentRepository? _documents;

  Future<NoteExportResult> export(
    Note note, {
    required AppStrings strings,
    /// Settled by the caller before the dialog opens.
    ///
    /// The desktop portals do not report which type was picked in their own
    /// dropdown, so the only thing left to read was the extension of the name
    /// we suggested: choosing Markdown there wrote plain text into a .txt.
    /// Requiring it here means no route reaches the dialog without knowing.
    required NoteExportFormat format,
    bool embedImages = false,
  }) async {
    final directory = await _paths.initialSaveDirectory();
    final safeTitle =
        _safeFileName(note.title.trim().isEmpty ? 'nota' : note.title);

    // If the app picked a format from the Save-as menu, the native dialog
    // only offers that type so the extension always matches.
    final groups = exportTypeGroups(format, strings);
    final location = await getSaveLocation(
      acceptedTypeGroups: groups,
      initialDirectory: directory.path,
      suggestedName: '$safeTitle.${format.extension}',
      confirmButtonText: strings.save,
      canCreateDirectories: true,
    );
    if (location == null) {
      throw const ExportCancelledException();
    }

    // Nothing to work out: the caller settled the format before we opened.
    final file = File(_ensureExtension(location.path, format.extension));
    return _writeNote(
      note,
      file,
      format,
      strings: strings,
      embedImages: embedImages,
    );
  }

  Future<NoteExportResult> saveAt(
    Note note,
    String path,
    NoteExportFormat format, {
    required AppStrings strings,
    bool includeAttachments = true,
    bool embedImages = false,
  }) async {
    final file = File(_ensureExtension(path, format.extension));
    return _writeNote(
      note,
      file,
      format,
      strings: strings,
      includeAttachments: includeAttachments,
      embedImages: embedImages,
    );
  }

  Future<NoteExportResult> _writeNote(
    Note note,
    File file,
    NoteExportFormat format, {
    required AppStrings strings,
    bool includeAttachments = true,
    bool embedImages = false,
  }) async {
    final usedSidecarNames = <String>{};
    final exportedAttachments = includeAttachments
        ? await _writeAttachments(note, file, usedSidecarNames)
        : const <_ExportedAttachment>[];
    // Inline images are encrypted, so reading them is asynchronous while the
    // HTML, RTF and PDF builders below are synchronous. Decrypt them all once
    // here; the builders then look them up from memory.
    await _preloadInlineImages(note.body);
    try {
      if (_isBinary(format)) {
        final bytes =
            await _renderBinary(note, format, exportedAttachments, strings);
        await file.writeAsBytes(bytes, flush: true);
      } else {
        // RTF has no way to point at a picture beside the document, so it always
        // embeds. The rest default to files on disk: smaller, readable, and the
        // images stay usable on their own.
        final sidecarImages = embedImages || format == NoteExportFormat.rtf
            ? const <String, String>{}
            : await _writeInlineImages(note.body, file, usedSidecarNames);
        await file.writeAsString(
          _render(note, format, exportedAttachments, sidecarImages, strings),
          flush: true,
        );
      }
    } finally {
      _inlineImageBytes.clear();
    }
    return NoteExportResult(file: file, format: format);
  }

  /// Decrypted inline images for the export in progress, keyed by absolute
  /// path. Populated by [_preloadInlineImages] and cleared when the export
  /// finishes, so nothing plaintext outlives the operation.
  final Map<String, Uint8List> _inlineImageBytes = {};

  Future<void> _preloadInlineImages(String body) async {
    _inlineImageBytes.clear();
    final documents = _documents;
    if (documents == null) return;
    for (final op in _deltaOps(body)) {
      final insert = op['insert'];
      if (insert is! Map || insert['image'] is! String) continue;
      final path = _localImageAbsolutePath(insert['image'] as String);
      if (path == null || _inlineImageBytes.containsKey(path)) continue;
      try {
        _inlineImageBytes[path] = await documents.readInlineImage(path);
      } catch (_) {
        // Missing or unreadable: the builders render their placeholder.
      }
    }
  }

  bool _isBinary(NoteExportFormat format) => format == NoteExportFormat.pdf;

  /// Folder written beside the document, holding attachments and inline images.
  String _sidecarFolderName(File mainFile) {
    final baseName = _safeFileName(
      p.basenameWithoutExtension(mainFile.path).trim().isEmpty
          ? 'nota'
          : p.basenameWithoutExtension(mainFile.path),
    );
    return '$baseName-adjuntos';
  }

  Future<Directory> _sidecarDirectory(File mainFile) async {
    final dir = Directory(
      p.join(p.dirname(mainFile.path), _sidecarFolderName(mainFile)),
    );
    await dir.create(recursive: true);
    return dir;
  }

  /// Writes the note's inline images beside the document, one file each, and
  /// maps every source to its path relative to the document.
  ///
  /// They used to be inlined as base64, which inflates each image by a third and
  /// buries the text under encoded blocks. JSON did not even do that: it kept
  /// absolute paths into the vault, which mean nothing on another machine and
  /// nothing on this one once the note is gone.
  Future<Map<String, String>> _writeInlineImages(
    String body,
    File mainFile,
    Set<String> used,
  ) async {
    if (_inlineImageBytes.isEmpty) return const {};
    final folderName = _sidecarFolderName(mainFile);
    final dir = await _sidecarDirectory(mainFile);
    final out = <String, String>{};
    var index = 1;
    for (final op in _deltaOps(body)) {
      final insert = op['insert'];
      if (insert is! Map || insert['image'] is! String) continue;
      final src = insert['image'] as String;
      if (out.containsKey(src)) continue;
      final absolute = _localImageAbsolutePath(src);
      if (absolute == null) continue;
      final bytes = _inlineImageBytes[absolute];
      if (bytes == null) continue;
      final name = _uniqueName(
        DocumentRepository.safeFileName(
          'imagen-$index${p.extension(absolute)}',
          fallback: 'imagen-$index.png',
        ),
        used,
      );
      used.add(name);
      await File(p.join(dir.path, name)).writeAsBytes(bytes, flush: true);
      // Forward slashes: these are read as links by Markdown and HTML, where a
      // Windows separator would be an escape character rather than a path.
      out[src] = '$folderName/$name';
      index++;
    }
    return out;
  }

  Future<List<_ExportedAttachment>> _writeAttachments(
    Note note,
    File mainFile,
    Set<String> used,
  ) async {
    if (_documents == null || note.attachments.isEmpty) {
      return const [];
    }
    final folderName = _sidecarFolderName(mainFile);
    final attachDir = await _sidecarDirectory(mainFile);

    final results = <_ExportedAttachment>[];
    for (final attachment in note.attachments) {
      final safeName = _uniqueName(_safeAttachmentName(attachment), used);
      used.add(safeName);
      final outFile = File(p.join(attachDir.path, safeName));
      final bytes = await _documents.read(attachment);
      await outFile.writeAsBytes(bytes, flush: true);
      results.add(_ExportedAttachment(
        originalName: attachment.originalName,
        relativePath: p.join(folderName, safeName),
      ));
    }
    return results;
  }

  String _safeAttachmentName(NoteAttachment attachment) {
    // Shares the hardened sanitiser rather than keeping a second, weaker copy:
    // this one only stripped the characters Windows forbids in a file name, so
    // an export folder could still receive names with shell metacharacters or
    // Windows device names in them.
    return DocumentRepository.safeFileName(
      attachment.originalName,
      fallback: '${attachment.id}.bin',
    );
  }

  String _uniqueName(String name, Set<String> used) {
    if (!used.contains(name)) return name;
    final ext = p.extension(name);
    final base = p.basenameWithoutExtension(name);
    var i = 1;
    while (used.contains('$base-$i$ext')) {
      i++;
    }
    return '$base-$i$ext';
  }


  Future<String> storagePath() async => (await _paths.appDirectory()).path;

  Future<String> exportsPath() async => (await _paths.exportsDirectory()).path;

  List<Map<String, dynamic>> _deltaOps(String body) {
    if (body.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(body);
      if (decoded is List) {
        return decoded.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
      }
    } catch (_) {}
    return [
      {'insert': body},
      {'insert': '\n'},
    ];
  }

  /// Resolves local file paths from the Quill image embed (and normal file:// URLs).
  String? _localImageAbsolutePath(String raw) {
    if (raw.startsWith('data:image/')) {
      return null;
    }
    if (raw.startsWith('file://')) {
      return Uri.tryParse(raw)?.toFilePath();
    }
    if (raw.startsWith('/') ||
        (Platform.isWindows && raw.length > 2 && raw[1] == ':')) {
      return raw;
    }
    return null;
  }

  String _mimeForImagePath(String path) {
    switch (p.extension(path).toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.bmp':
        return 'image/bmp';
      case '.png':
      default:
        return 'image/png';
    }
  }

  /// Reads local image file into a `data:` URL for self-contained HTML / Markdown.
  String? _imageToDataUrlForExport(String rawSource) {
    final path = _localImageAbsolutePath(rawSource);
    if (path == null) return null;
    final bytes = _inlineImageBytes[path];
    if (bytes == null) return null;
    return 'data:${_mimeForImagePath(path)};base64,${base64Encode(bytes)}';
  }

  List<Map<String, dynamic>> _deltaOpsWithDataUrlImages(String body) {
    final ops = _deltaOps(body);
    final out = <Map<String, dynamic>>[];
    for (final op in ops) {
      final insert = op['insert'];
      if (insert is Map && insert['image'] is String) {
        final src = insert['image'] as String;
        final dataUrl = _imageToDataUrlForExport(src);
        if (dataUrl != null) {
          final m = Map<String, dynamic>.from(op);
          m['insert'] = <String, String>{'image': dataUrl};
          out.add(m);
          continue;
        }
      }
      out.add(Map<String, dynamic>.from(op));
    }
    return out;
  }

  String _rtfHexPicture(Uint8List bytes, {required bool isJpeg}) {
    final blip = isJpeg ? r'\jpegblip' : r'\pngblip';
    final hex = StringBuffer();
    for (final b in bytes) {
      hex.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return '{\\*\\shppict{\\pict$blip\\picwgoal5000\\pichgoal4000\n'
        '${hex.toString()}\n}}\n\\par ';
  }

  void _appendRtfImage(StringBuffer buf, String rawSource) {
    final path = _localImageAbsolutePath(rawSource);
    if (path == null) {
      buf.write(_rtfEscape('[imagen]'));
      buf.write(r'\par ');
      return;
    }
    final bytes = _inlineImageBytes[path];
    if (bytes == null) {
      buf.write(_rtfEscape('[imagen no encontrada]'));
      buf.write(r'\par ');
      return;
    }
    try {
      final ext = p.extension(path).toLowerCase();
      final isJpeg = ext == '.jpg' || ext == '.jpeg';
      buf.write(_rtfHexPicture(bytes, isJpeg: isJpeg));
    } catch (_) {
      buf.write(_rtfEscape('[imagen]'));
      buf.write(r'\par ');
    }
  }

  String _plainText(String body) {
    final ops = _deltaOps(body);
    final buffer = StringBuffer();
    for (final op in ops) {
      final insert = op['insert'];
      if (insert is Map && insert['image'] != null) {
        buffer.write('[image]');
        continue;
      }
      if (insert is! String) continue;
      final attrs = op['attributes'] as Map?;
      final link = attrs?['link'];
      if (link is String && insert.trim().isNotEmpty && insert.trim() != link) {
        buffer.write('$insert ($link)');
      } else {
        buffer.write(insert);
      }
    }
    return buffer.toString();
  }

  String _toMarkdown(String body, Map<String, String> sidecarImages) {
    final ops = _deltaOps(body);
    final buffer = StringBuffer();
    var atLineStart = true;
    for (final op in ops) {
      final insert = op['insert'];
      if (insert is Map && insert['image'] is String) {
        final src = insert['image'] as String;
        final sidecar = sidecarImages[src];
        if (sidecar != null) {
          buffer.write('![](${Uri.encodeFull(sidecar)})\n\n');
        } else {
          buffer.write('![](${_imageToDataUrlForExport(src) ?? src})\n\n');
        }
        atLineStart = true;
        continue;
      }
      if (insert is! String) continue;
      final attrs = op['attributes'] as Map?;
      final lines = insert.split('\n');
      for (var i = 0; i < lines.length; i++) {
        final isLast = i == lines.length - 1;
        var segment = lines[i];
        if (segment.isNotEmpty && attrs != null) {
          if (attrs['code'] == true) segment = '`$segment`';
          if (attrs['strike'] == true) segment = '~~$segment~~';
          if (attrs['underline'] == true) segment = '<u>$segment</u>';
          if (attrs['italic'] == true) segment = '*$segment*';
          if (attrs['bold'] == true) segment = '**$segment**';
          // Markdown has no colour syntax, but every renderer worth using
          // passes inline HTML through — the same trick <u> above relies on.
          final styles = <String>[];
          final color = attrs['color'];
          if (color is String) {
            final hex = normaliseColor(color);
            if (hex != null) styles.add('color:$hex');
          }
          final background = attrs['background'];
          if (background is String) {
            final hex = normaliseColor(background);
            if (hex != null) styles.add('background-color:$hex');
          }
          if (styles.isNotEmpty) {
            segment = '<span style="${styles.join(';')}">$segment</span>';
          }
          final link = attrs['link'];
          if (link is String && link.isNotEmpty) {
            segment = '[$segment]($link)';
          }
        }
        if (atLineStart && attrs != null) {
          final header = attrs['header'];
          if (header is int) {
            buffer.write('${'#' * header} ');
          } else if (attrs['list'] == 'bullet') {
            buffer.write('- ');
          } else if (attrs['list'] == 'ordered') {
            buffer.write('1. ');
          } else if (attrs['blockquote'] == true) {
            buffer.write('> ');
          }
        }
        buffer.write(segment);
        if (!isLast) {
          buffer.write('\n');
          atLineStart = true;
        } else {
          atLineStart = false;
        }
      }
    }
    return buffer.toString();
  }

  String _toRtfDocument(
    Note note,
    List<_ExportedAttachment> attachments,
    AppStrings strings,
  ) {
    final ops = _deltaOps(note.body);
    // RTF refers to colours by index into a table declared up front, so every
    // colour the note uses has to be collected before writing any text. Index 0
    // is "auto"; black is 1, and the document's own colours follow.
    final colorIndex = _rtfColorTable(ops);
    final buf = StringBuffer();
    buf.write(r'{\rtf1\ansi\ansicpg1252\deff0\nouicompat'
        r'{\fonttbl{\f0\fnil\fcharset0 Helvetica;}{\f1\fnil\fcharset0 Courier New;}}');
    buf.write(r'{\colortbl ;\red0\green0\blue0;');
    for (final hex in colorIndex.keys) {
      final r = int.parse(hex.substring(1, 3), radix: 16);
      final g = int.parse(hex.substring(3, 5), radix: 16);
      final b = int.parse(hex.substring(5, 7), radix: 16);
      buf.write('\\red$r\\green$g\\blue$b;');
    }
    buf.write('}');
    buf.write(r'\f0\fs22 ');
    if (note.title.isNotEmpty) {
      buf.write(r'\b\fs32 ');
      buf.write(_rtfEscape(note.title));
      buf.write(r'\b0\fs22\par\par ');
    }
    if (note.tags.isNotEmpty) {
      buf.write(r'\i ');
      buf.write(_rtfEscape('${strings.tagsLabel}: ${note.tags.join(', ')}'));
      buf.write(r'\i0\par\par ');
    }
    for (final op in ops) {
      final insert = op['insert'];
      if (insert is Map && insert['image'] is String) {
        _appendRtfImage(buf, insert['image'] as String);
        continue;
      }
      if (insert is! String) continue;
      final attrs = op['attributes'] as Map?;
      final lines = insert.split('\n');
      for (var i = 0; i < lines.length; i++) {
        var segment = _rtfEscape(lines[i]);
        var openTags = '';
        var closeTags = '';
        if (attrs != null) {
          if (attrs['code'] == true) {
            openTags += r'\f1 ';
            closeTags = r'\f0 ' + closeTags;
          }
          if (attrs['bold'] == true) {
            openTags += r'\b ';
            closeTags = r'\b0 ' + closeTags;
          }
          if (attrs['italic'] == true) {
            openTags += r'\i ';
            closeTags = r'\i0 ' + closeTags;
          }
          if (attrs['underline'] == true) {
            openTags += r'\ul ';
            closeTags = r'\ulnone ' + closeTags;
          }
          if (attrs['strike'] == true) {
            openTags += r'\strike ';
            closeTags = r'\strike0 ' + closeTags;
          }
          final color = attrs['color'];
          if (color is String) {
            final index = colorIndex[normaliseColor(color)];
            if (index != null) {
              openTags += '\\cf$index ';
              closeTags = '\\cf0 $closeTags';
            }
          }
          final background = attrs['background'];
          if (background is String) {
            final index = colorIndex[normaliseColor(background)];
            if (index != null) {
              // \highlight is what Word honours; \cb is widely ignored.
              openTags += '\\highlight$index ';
              closeTags = '\\highlight0 $closeTags';
            }
          }
          final link = attrs['link'];
          if (link is String && link.isNotEmpty) {
            final url = _rtfEscape(link);
            segment =
                '{\\field{\\*\\fldinst{HYPERLINK "$url"}}{\\fldrslt $segment}}';
          }
        }
        buf.write('$openTags$segment$closeTags');
        if (i < lines.length - 1) {
          buf.write(r'\par ');
        }
      }
    }
    if (attachments.isNotEmpty) {
      buf.write(r'\par\par\b Adjuntos\b0\par ');
      for (final a in attachments) {
        buf.write(_rtfEscape('• ${a.originalName}  (${a.relativePath})'));
        buf.write(r'\par ');
      }
    }
    buf.write('}');
    return buf.toString();
  }

  /// Every colour the note uses, mapped to its RTF colour-table index.
  ///
  /// Indices start at 2: the table always declares "auto" at 0 and black at 1.
  Map<String, int> _rtfColorTable(List<Map<String, dynamic>> ops) {
    final table = <String, int>{};
    for (final op in ops) {
      final attrs = op['attributes'];
      if (attrs is! Map) continue;
      for (final key in const ['color', 'background']) {
        final raw = attrs[key];
        if (raw is! String) continue;
        final hex = normaliseColor(raw);
        if (hex == null || table.containsKey(hex)) continue;
        table[hex] = table.length + 2;
      }
    }
    return table;
  }

  String _rtfEscape(String value) {
    final out = StringBuffer();
    for (final rune in value.runes) {
      if (rune == 0x5C) {
        out.write(r'\\');
      } else if (rune == 0x7B) {
        out.write(r'\{');
      } else if (rune == 0x7D) {
        out.write(r'\}');
      } else if (rune < 128) {
        out.writeCharCode(rune);
      } else {
        var signed = rune;
        if (signed > 32767) signed -= 65536;
        out.write('\\u$signed?');
      }
    }
    return out.toString();
  }

  Future<Uint8List> _toPdf(
    Note note,
    List<_ExportedAttachment> attachments,
    AppStrings strings,
  ) async {
    final doc = pw.Document();
    final ops = _deltaOps(note.body);
    final bodyWidgets = _pdfBodyWidgets(ops);
    doc.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.fromLTRB(48, 56, 48, 56),
        build: (context) {
          return [
            pw.Text(
              note.title.isEmpty ? strings.untitled : note.title,
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            if (note.tags.isNotEmpty) ...[
              pw.SizedBox(height: 4),
              pw.Text(
                '${strings.tagsLabel}: ${note.tags.join(', ')}',
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),
            ],
            pw.SizedBox(height: 16),
            ...bodyWidgets,
            // No attachment list here on purpose. A PDF is the format people
            // send on its own, and the list names files with paths into a
            // sibling folder the reader does not have — noise at best,
            // misleading at worst. The text formats keep it, since those
            // travel next to the exported folder.
          ];
        },
      ),
    );
    return doc.save();
  }

  List<pw.Widget> _pdfBodyWidgets(List<Map<String, dynamic>> ops) {
    final widgets = <pw.Widget>[];
    final lineSpans = <pw.InlineSpan>[];
    Map<String, dynamic>? blockAttrs;

    void flushLine() {
      final isCode = blockAttrs?['code-block'] == true;
      final header = blockAttrs?['header'];
      final isQuote = blockAttrs?['blockquote'] == true;
      pw.Widget child;
      if (lineSpans.isEmpty) {
        child = pw.SizedBox(height: 6);
      } else if (header is int && header > 0) {
        child = pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8, bottom: 4),
          child: pw.RichText(
            text: pw.TextSpan(
              children: lineSpans
                  .map((s) => s is pw.TextSpan
                      ? pw.TextSpan(
                          text: s.text,
                          style: (s.style ?? const pw.TextStyle()).copyWith(
                            fontSize: header == 1 ? 18 : (header == 2 ? 15 : 13),
                            fontWeight: pw.FontWeight.bold,
                          ),
                        )
                      : s)
                  .toList(),
            ),
          ),
        );
      } else if (isCode) {
        child = pw.Container(
          width: double.infinity,
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: pw.RichText(text: pw.TextSpan(children: List.of(lineSpans))),
        );
      } else if (isQuote) {
        child = pw.Container(
          padding: const pw.EdgeInsets.only(left: 10),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              left: pw.BorderSide(color: PdfColors.grey400, width: 2),
            ),
          ),
          child: pw.RichText(text: pw.TextSpan(children: List.of(lineSpans))),
        );
      } else if (blockAttrs?['list'] == 'bullet' ||
          blockAttrs?['list'] == 'ordered') {
        final marker = blockAttrs?['list'] == 'ordered' ? '1. ' : '•  ';
        child = pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(marker),
            pw.Expanded(
              child: pw.RichText(
                text: pw.TextSpan(children: List.of(lineSpans)),
              ),
            ),
          ],
        );
      } else {
        child = pw.RichText(text: pw.TextSpan(children: List.of(lineSpans)));
      }
      widgets.add(child);
      lineSpans.clear();
      blockAttrs = null;
    }

    for (final op in ops) {
      final insert = op['insert'];
      if (insert is Map && insert['image'] is String) {
        if (lineSpans.isNotEmpty) flushLine();
        final path = _localImageAbsolutePath(insert['image'] as String);
        if (path != null) {
          try {
            final bytes = _inlineImageBytes[path];
            if (bytes != null) {
              widgets.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 10),
                  child: pw.Center(
                    child: pw.Image(
                      pw.MemoryImage(bytes),
                      width: 420,
                      fit: pw.BoxFit.contain,
                    ),
                  ),
                ),
              );
            }
          } catch (_) {}
        }
        continue;
      }
      if (insert is! String) continue;
      final attrs = op['attributes'] as Map?;
      final inlineStyle = _pdfInlineStyle(attrs);
      final link = attrs?['link'];
      final lines = insert.split('\n');
      for (var i = 0; i < lines.length; i++) {
        final text = lines[i];
        if (text.isNotEmpty) {
          lineSpans.add(
            pw.TextSpan(
              text: text,
              style: link is String
                  ? inlineStyle.copyWith(
                      color: PdfColors.blue700,
                      decoration: pw.TextDecoration.underline,
                    )
                  : inlineStyle,
            ),
          );
          if (link is String && link.isNotEmpty && link != text) {
            lineSpans.add(
              pw.TextSpan(
                text: ' ($link)',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey600,
                ),
              ),
            );
          }
        }
        if (i < lines.length - 1) {
          if (attrs != null) {
            blockAttrs = Map<String, dynamic>.from(attrs);
          }
          flushLine();
        }
      }
    }
    if (lineSpans.isNotEmpty) flushLine();
    return widgets;
  }

  pw.TextStyle _pdfInlineStyle(Map? attrs) {
    var style = const pw.TextStyle(fontSize: 11);
    if (attrs == null) return style;
    if (attrs['bold'] == true) {
      style = style.copyWith(fontWeight: pw.FontWeight.bold);
    }
    if (attrs['italic'] == true) {
      style = style.copyWith(fontStyle: pw.FontStyle.italic);
    }
    if (attrs['underline'] == true) {
      style = style.copyWith(decoration: pw.TextDecoration.underline);
    }
    if (attrs['strike'] == true) {
      style = style.copyWith(decoration: pw.TextDecoration.lineThrough);
    }
    if (attrs['code'] == true) {
      style = style.copyWith(font: pw.Font.courier(), fontSize: 10);
    }
    final color = attrs['color'];
    if (color is String) {
      final parsed = _parseHexColor(color);
      if (parsed != null) {
        style = style.copyWith(color: parsed);
      }
    }
    // Highlight. TextStyle.background takes a BoxDecoration, not a colour,
    // which is why this was missed: text colour worked while highlighting
    // silently did nothing in exported PDFs.
    final background = attrs['background'];
    if (background is String) {
      final parsed = _parseHexColor(background);
      if (parsed != null) {
        style = style.copyWith(background: pw.BoxDecoration(color: parsed));
      }
    }
    return style;
  }

  /// Normalises a colour from a Quill attribute to `#rrggbb`.
  ///
  /// The editor writes hex, but not always the same shape, and a pasted
  /// document can carry `rgb()` or `rgba()`. Returning one canonical form keeps
  /// every exporter from having to parse colours itself.
  static String? normaliseColor(String raw) {
    var v = raw.trim().toLowerCase();
    if (v.isEmpty || v == 'transparent') return null;

    final rgb = RegExp(r'^rgba?\(([^)]*)\)$').firstMatch(v);
    if (rgb != null) {
      final parts = rgb.group(1)!.split(',');
      if (parts.length < 3) return null;
      final channels = <int>[];
      for (var i = 0; i < 3; i++) {
        final n = int.tryParse(parts[i].trim());
        if (n == null || n < 0 || n > 255) return null;
        channels.add(n);
      }
      return '#${channels.map((c) => c.toRadixString(16).padLeft(2, '0')).join()}';
    }

    if (v.startsWith('#')) v = v.substring(1);
    if (!RegExp(r'^[0-9a-f]+$').hasMatch(v)) return null;
    // #rgb shorthand doubles each digit; #aarrggbb drops the alpha, which no
    // export format here can represent anyway.
    if (v.length == 3) v = v.split('').map((c) => '$c$c').join();
    if (v.length == 8) v = v.substring(2);
    if (v.length != 6) return null;
    return '#$v';
  }

  PdfColor? _parseHexColor(String value) {
    final normalised = normaliseColor(value);
    if (normalised == null) return null;
    try {
      return PdfColor.fromInt(int.parse('FF${normalised.substring(1)}', radix: 16));
    } catch (_) {
      return null;
    }
  }

  /// Same shape as [_deltaOpsWithDataUrlImages], but pointing at the files
  /// written beside the document instead of carrying them inline.
  List<Map<String, dynamic>> _deltaOpsWithSidecarImages(
    String body,
    Map<String, String> sidecarImages,
  ) {
    final out = <Map<String, dynamic>>[];
    for (final op in _deltaOps(body)) {
      final insert = op['insert'];
      if (insert is Map && insert['image'] is String) {
        final replacement = sidecarImages[insert['image'] as String];
        if (replacement != null) {
          final m = Map<String, dynamic>.from(op);
          m['insert'] = <String, String>{'image': replacement};
          out.add(m);
          continue;
        }
      }
      out.add(Map<String, dynamic>.from(op));
    }
    return out;
  }

  String _toHtml(String body, Map<String, String> sidecarImages) {
    final ops = sidecarImages.isEmpty
        ? _deltaOpsWithDataUrlImages(body)
        : _deltaOpsWithSidecarImages(body, sidecarImages);
    if (ops.isEmpty) return '';
    final converter = QuillDeltaToHtmlConverter(ops);
    return converter.convert();
  }

  Future<Uint8List> _renderBinary(
    Note note,
    NoteExportFormat format,
    List<_ExportedAttachment> attachments,
    AppStrings strings,
  ) {
    switch (format) {
      case NoteExportFormat.pdf:
        return _toPdf(note, attachments, strings);
      default:
        throw StateError('No es un formato binario: $format');
    }
  }

  String _render(
    Note note,
    NoteExportFormat format,
    List<_ExportedAttachment> attachments,
    Map<String, String> sidecarImages,
    AppStrings strings,
  ) {
    switch (format) {
      case NoteExportFormat.pdf:
        throw StateError('PDF se exporta en binario.');
      case NoteExportFormat.rtf:
        return _toRtfDocument(note, attachments, strings);
      case NoteExportFormat.txt:
        final tags = note.tags.isEmpty
            ? ''
            : '\n${strings.tagsLabel}: ${note.tags.join(', ')}\n';
        final attachSection = attachments.isEmpty
            ? ''
            : '\n---\n${strings.attachments}:\n${attachments.map((a) => '- ${a.originalName}  (${a.relativePath})').join('\n')}\n';
        return '${note.title}\n${'=' * note.title.length}\n$tags\n${_plainText(note.body)}\n$attachSection';
      case NoteExportFormat.markdown:
        final tags = note.tags.isEmpty
            ? ''
            : '\n\n**${strings.tagsLabel}:** ${note.tags.join(', ')}';
        final attachSection = attachments.isEmpty
            ? ''
            : '\n\n## ${strings.attachments}\n${attachments.map((a) => '- [${a.originalName}](${Uri.encodeFull(a.relativePath)})').join('\n')}\n';
        return '# ${note.title}\n\n${_toMarkdown(note.body, sidecarImages)}$tags$attachSection\n';
      case NoteExportFormat.json:
        final delta = _deltaOpsWithSidecarImages(note.body, sidecarImages);
        return const JsonEncoder.withIndent('  ').convert({
          'title': note.title,
          'tags': note.tags,
          'createdAt': note.createdAt.toIso8601String(),
          'updatedAt': note.updatedAt.toIso8601String(),
          'body': delta,
          'attachments': [
            for (final a in attachments)
              {'name': a.originalName, 'path': a.relativePath},
          ],
        });
      case NoteExportFormat.html:
        final body = _toHtml(note.body, sidecarImages);
        final attachSection = attachments.isEmpty
            ? ''
            : '''
  <h2>${_escapeHtml(strings.attachments)}</h2>
  <ul>
    ${attachments.map((a) => '<li><a href="${Uri.encodeFull(a.relativePath)}">${_escapeHtml(a.originalName)}</a></li>').join('\n    ')}
  </ul>''';
        return '''
<!doctype html>
<html lang="${strings.htmlLangCode}">
<head>
  <meta charset="utf-8">
  <title>${_escapeHtml(note.title)}</title>
  <style>
    body { font-family: -apple-system, system-ui, sans-serif; max-width: 720px; margin: 32px auto; padding: 0 16px; line-height: 1.6; color: #1c1c1e; }
    h1, h2, h3 { letter-spacing: -0.01em; }
    blockquote { border-left: 3px solid #d1d1d6; padding-left: 12px; color: #6c6c70; }
    code { background: #f5f5f7; padding: 2px 5px; border-radius: 4px; font-family: monospace; }
    pre { background: #f6f8fa; padding: 12px 14px; border-radius: 8px; border: 1px solid #e5e7eb; overflow:auto; }
    a { color: #0a66c2; }
    img { max-width: 100%; height: auto; border-radius: 8px; margin: 12px 0; }
  </style>
</head>
<body>
  <h1>${_escapeHtml(note.title)}</h1>
  $body
  $attachSection
</body>
</html>
''';
    }
  }

  String _safeFileName(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9áéíóúñü]+', caseSensitive: false), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '')
        .trim();
  }

  /// Guarantees the file name ends with the extension matching its contents.
  ///
  /// This used to append only when there was no extension at all, which broke
  /// two ordinary cases. A name containing a dot — "Reunión 20.08", "nota v1.2"
  /// — looked like it already had one, so the file was written with no usable
  /// extension and other devices reported it as damaged. And choosing PDF while
  /// the name ended in `.txt` left the mismatch in place, putting PDF bytes in
  /// a file everything would try to read as text.
  String _ensureExtension(String path, String extension) {
    final current = p.extension(path).replaceFirst('.', '').toLowerCase();
    if (current == extension.toLowerCase()) return path;
    return '$path.$extension';
  }

  String _escapeHtml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}

class ExportCancelledException implements Exception {
  const ExportCancelledException();

  @override
  String toString() => 'Export cancelled.';
}

class _ExportedAttachment {
  const _ExportedAttachment({
    required this.originalName,
    required this.relativePath,
  });

  final String originalName;
  final String relativePath;
}

class NoteExportResult {
  const NoteExportResult({required this.file, required this.format});

  final File file;
  final NoteExportFormat format;
}
