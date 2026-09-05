import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_app/features/notes/presentation/notes_home_page.dart';

void main() {
  // A highlight is picked for the page, not for the theme. In dark mode the
  // letters are near-white, so a pale yellow highlight left them invisible.
  group('letters on a highlight', () {
    test('a pale highlight in dark mode turns the letters dark', () {
      for (final pale in ['#ffff00', '#ffffff', '#ffe0b2']) {
        final colour = textColourOnHighlight(pale, Brightness.dark);
        expect(colour, isNotNull, reason: pale);
        expect(colour!.computeLuminance(), lessThan(0.2), reason: pale);
      }
    });

    test('a dark highlight in light mode turns the letters light', () {
      for (final dark in ['#000080', '#000000', '#3b0a45']) {
        final colour = textColourOnHighlight(dark, Brightness.light);
        expect(colour, isNotNull, reason: dark);
        expect(colour!.computeLuminance(), greaterThan(0.8), reason: dark);
      }
    });

    // The whole point of being surgical: where the two already contrast, the
    // text keeps whatever colour it was given.
    test('leaves readable pairings alone', () {
      expect(textColourOnHighlight('#ffff00', Brightness.light), isNull);
      expect(textColourOnHighlight('#000080', Brightness.dark), isNull);
    });

    test('accepts the shapes a picker or a paste can produce', () {
      expect(textColourOnHighlight('#FFFF00', Brightness.dark), isNotNull);
      expect(textColourOnHighlight('ffff00', Brightness.dark), isNotNull);
      expect(textColourOnHighlight('#ff0', Brightness.dark), isNotNull);
      expect(
        textColourOnHighlight('rgb(255, 255, 0)', Brightness.dark),
        isNotNull,
      );
    });

    test('leaves the text alone when the colour makes no sense', () {
      for (final junk in ['', 'transparent', 'chartreuse', '#12345']) {
        expect(textColourOnHighlight(junk, Brightness.dark), isNull,
            reason: junk);
      }
    });
  });
}
