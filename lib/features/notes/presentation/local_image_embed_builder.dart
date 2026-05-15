import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

class LocalFileImageEmbedBuilder extends EmbedBuilder {
  const LocalFileImageEmbedBuilder();

  @override
  String get key => BlockEmbed.imageType;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final raw = embedContext.node.value.data;
    if (raw is! String) return const SizedBox.shrink();
    final path =
        raw.startsWith('file://') ? Uri.parse(raw).toFilePath() : raw;
    final file = File(path);
    if (!file.existsSync()) {
      final es = Localizations.localeOf(context).languageCode == 'es';
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          es ? 'Imagen no encontrada' : 'Image not found',
          style: embedContext.textStyle,
        ),
      );
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
            child: Image.file(
              file,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              isAntiAlias: true,
              errorBuilder: (context, error, stack) {
                final es =
                    Localizations.localeOf(context).languageCode == 'es';
                return Text(
                  es ? 'No se pudo cargar la imagen' : 'Could not load image',
                  style: embedContext.textStyle,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
