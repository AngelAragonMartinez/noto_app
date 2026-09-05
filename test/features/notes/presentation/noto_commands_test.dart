import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_app/app/app_strings.dart';
import 'package:notes_app/features/notes/presentation/noto_commands.dart';

void main() {
  final es = AppStrings(const Locale('es'));
  final en = AppStrings(const Locale('en'));

  group('the command table', () {
    // Two commands on one combination means one of them silently never fires.
    test('no two commands claim the same shortcut', () {
      final seen = <String, NotoCommand>{};
      for (final command in NotoCommand.values) {
        final shortcut = command.shortcut;
        if (shortcut == null) continue;
        final key = shortcutLabel(shortcut);
        expect(
          seen[key],
          isNull,
          reason: '$key is claimed by both ${seen[key]} and $command',
        );
        seen[key] = command;
      }
    });

    test('every command is named in both languages', () {
      for (final command in NotoCommand.values) {
        expect(command.label(es).trim(), isNotEmpty, reason: '$command in es');
        expect(command.label(en).trim(), isNotEmpty, reason: '$command in en');
      }
    });

    test('every menu holds at least one command', () {
      for (final menu in NotoMenu.values) {
        expect(NotoCommand.inMenu(menu), isNotEmpty, reason: '$menu');
        expect(menu.label(es).trim(), isNotEmpty);
        expect(menu.label(en).trim(), isNotEmpty);
      }
    });

    test('every command shown belongs to a menu that exists', () {
      final shown = {
        for (final menu in NotoMenu.values) ...NotoCommand.inMenu(menu),
      };
      final expected =
          NotoCommand.values.where((c) => !c.hidden).toSet();
      expect(shown, expected);
    });

    // A command that draws no row is reachable only by its keys. Without one it
    // would exist in the table and nowhere else.
    test('a command with no row of its own still has a shortcut', () {
      for (final command in NotoCommand.values.where((c) => c.hidden)) {
        expect(command.shortcut, isNotNull, reason: '$command');
      }
    });
  });

  group('shortcut labels', () {
    test('read the way a menu writes them', () {
      expect(
        shortcutLabel(const SingleActivator(LogicalKeyboardKey.keyN,
            control: true)),
        'Ctrl+N',
      );
      expect(
        shortcutLabel(const SingleActivator(LogicalKeyboardKey.keyS,
            control: true, shift: true)),
        'Ctrl+Shift+S',
      );
      expect(
        shortcutLabel(const SingleActivator(LogicalKeyboardKey.f1)),
        'F1',
      );
      expect(
        shortcutLabel(const SingleActivator(LogicalKeyboardKey.delete,
            control: true)),
        'Ctrl+Supr',
      );
    });

    // Derived from the activator, never typed beside it: a rebinding shows up
    // in the guide by itself.
    test('follow the table rather than a hand-written copy', () {
      expect(shortcutLabel(NotoCommand.save.shortcut!), 'Ctrl+S');
      expect(shortcutLabel(NotoCommand.saveAs.shortcut!), 'Ctrl+Shift+S');
      expect(shortcutLabel(NotoCommand.shortcutsGuide.shortcut!), 'F1');
    });
  });
}
