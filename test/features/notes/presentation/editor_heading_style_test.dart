import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_app/features/notes/presentation/notes_home_page.dart';

void main() {
  group('editor heading style', () {
    // The built-in heading styles pin a colour, and a pinned colour wins over
    // the colour attribute on the text itself, so colouring or highlighting a
    // title did nothing on screen. The attribute was stored and exported
    // correctly the whole time — see export_colors_test.dart — which is why the
    // fix belongs here and not in the exporters.
    test('pins no colour, so the text keeps its own', () {
      for (final size in [30.0, 24.0, 20.0]) {
        expect(notoHeadingStyle(size).style.color, isNull, reason: '$size');
        expect(notoHeadingStyle(size).style.backgroundColor, isNull);
      }
    });

    test('still looks like a heading', () {
      final h1 = notoHeadingStyle(30).style;

      expect(h1.fontSize, 30);
      expect(h1.fontWeight, FontWeight.w600);
      expect(h1.decoration, TextDecoration.none);
    });

    test('sizes stay ordered from h1 down to h3', () {
      expect(notoHeadingStyle(30).style.fontSize!,
          greaterThan(notoHeadingStyle(24).style.fontSize!));
      expect(notoHeadingStyle(24).style.fontSize!,
          greaterThan(notoHeadingStyle(20).style.fontSize!));
    });
  });
}
