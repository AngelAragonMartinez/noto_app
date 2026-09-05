import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_app/app/app_strings.dart';
import 'package:notes_app/features/notes/data/note_export_repository.dart';

void main() {
  final s = AppStrings(const Locale('es'));

  group('the types the save dialog offers', () {
    // Save once as text and text became the only thing ever offered again: the
    // remembered default was passed as the preferred format, which narrows the
    // dialog to a single type.
    test('every format, when none was asked for by name', () {
      final groups = exportTypeGroups(null, s);

      expect(groups, hasLength(NoteExportFormat.values.length));
      final extensions = groups
          .expand((g) => g.extensions ?? const <String>[])
          .toSet();
      expect(
        extensions,
        NoteExportFormat.values.map((f) => f.extension).toSet(),
      );
    });

    test('just the one, when a format was asked for by name', () {
      for (final format in NoteExportFormat.values) {
        final groups = exportTypeGroups(format, s);

        expect(groups, hasLength(1), reason: format.name);
        expect(groups.single.extensions, [format.extension]);
      }
    });

    test('every offered type is named', () {
      for (final group in exportTypeGroups(null, s)) {
        expect(group.label, isNotNull);
        expect(group.label!.trim(), isNotEmpty);
      }
    });
  });
}
