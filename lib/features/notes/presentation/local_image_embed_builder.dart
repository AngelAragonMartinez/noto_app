import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../documents/data/document_repository.dart';

/// Renders images embedded in a note body.
///
/// Images are stored encrypted, so decoding is asynchronous. Results are held
/// in a small shared cache: Quill rebuilds embeds while the user types, and
/// decrypting a multi-megabyte image on every keystroke would stall the editor.
class LocalFileImageEmbedBuilder extends EmbedBuilder {
  const LocalFileImageEmbedBuilder({required this.documents});

  final DocumentRepository documents;

  @override
  String get key => BlockEmbed.imageType;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final raw = embedContext.node.value.data;
    if (raw is! String || raw.isEmpty) return const SizedBox.shrink();
    return _InlineImage(
      documents: documents,
      source: raw,
      textStyle: embedContext.textStyle,
    );
  }
}

/// Bounded LRU of decrypted image bytes, keyed by the note body's image source.
class _DecryptedImageCache {
  static const _maxEntries = 24;
  static final LinkedHashMap<String, Future<Uint8List>> _entries =
      LinkedHashMap();

  static Future<Uint8List> get(
    String source,
    Future<Uint8List> Function() load,
  ) {
    final existing = _entries.remove(source);
    if (existing != null) {
      _entries[source] = existing; // reinsert as most recently used
      return existing;
    }
    final future = load();
    _entries[source] = future;
    while (_entries.length > _maxEntries) {
      _entries.remove(_entries.keys.first);
    }
    return future;
  }
}

class _InlineImage extends StatefulWidget {
  const _InlineImage({
    required this.documents,
    required this.source,
    required this.textStyle,
  });

  final DocumentRepository documents;
  final String source;
  final TextStyle? textStyle;

  @override
  State<_InlineImage> createState() => _InlineImageState();
}

class _InlineImageState extends State<_InlineImage> {
  late Future<Uint8List> _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = _load();
  }

  @override
  void didUpdateWidget(_InlineImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _bytes = _load();
    }
  }

  Future<Uint8List> _load() => _DecryptedImageCache.get(
        widget.source,
        () => widget.documents.readInlineImage(widget.source),
      );

  Widget _message(String es, String en) {
    final spanish = Localizations.localeOf(context).languageCode == 'es';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(spanish ? es : en, style: widget.textStyle),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _bytes,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _message('Imagen no encontrada', 'Image not found');
        }
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Align(
            alignment: Alignment.centerLeft,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 760,
                  maxHeight: 560,
                ),
                child: Image.memory(
                  snapshot.data!,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                  isAntiAlias: true,
                  errorBuilder: (context, error, stack) => _message(
                    'No se pudo cargar la imagen',
                    'Could not load image',
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
