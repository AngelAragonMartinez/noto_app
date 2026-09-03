import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../app/app_strings.dart';
import '../../../app/locale_controller.dart';
import '../../../app/theme_controller.dart';
import '../../../app/ui_preferences.dart';
import '../../about/about_dialog.dart';
import '../application/notes_controller.dart';
import 'noto_commands.dart';
import 'shortcuts_dialog.dart';

/// The editor currently on screen, or null when no note is open.
///
/// The formatting commands have to reach the document the user is looking at,
/// and the menu bar sits well above it. The editor publishes itself here while
/// it is mounted; menu entries that need it are disabled when it is null, which
/// is also how the File entries behave with no note selected.
final activeEditorProvider = StateProvider<QuillController?>((ref) => null);

/// The open editor's find bar toggle, published while an editor is mounted.
///
/// Find lives inside the editor and always did; the menu entry needs a way to
/// pull the same lever rather than growing a second one beside it.
final activeFindToggleProvider = StateProvider<VoidCallback?>((ref) => null);

/// Focus for the notes list search box, so the menu can put the caret in it.
final notesSearchFocusProvider = Provider<FocusNode>((ref) {
  final node = FocusNode(debugLabel: 'notes search');
  ref.onDispose(node.dispose);
  return node;
});

/// Carries a command from a key press to the one place that runs it.
class NotoCommandIntent extends Intent {
  const NotoCommandIntent(this.command);

  final NotoCommand command;
}

/// Whether [command] can run right now.
bool canRunNotoCommand(WidgetRef ref, NotoCommand command) {
  final state = ref.read(notesControllerProvider);
  final hasNote = state.selectedNote != null;
  final editable = hasNote && !state.showTrash;
  switch (command) {
    case NotoCommand.newNote:
    case NotoCommand.importNote:
    case NotoCommand.toggleTrash:
    case NotoCommand.toggleToolbar:
    case NotoCommand.embedImages:
    case NotoCommand.toggleSidebar:
    case NotoCommand.cycleTheme:
    case NotoCommand.toggleLanguage:
    case NotoCommand.shortcutsGuide:
    case NotoCommand.about:
    case NotoCommand.quit:
      return true;
    case NotoCommand.save:
    case NotoCommand.saveAs:
      return hasNote;
    case NotoCommand.attach:
    case NotoCommand.moveToTrash:
      return editable;
    case NotoCommand.undo:
    case NotoCommand.redo:
    case NotoCommand.bold:
    case NotoCommand.italic:
    case NotoCommand.underline:
    case NotoCommand.heading1:
    case NotoCommand.heading2:
    case NotoCommand.heading3:
      return editable && ref.read(activeEditorProvider) != null;
    case NotoCommand.find:
      return editable && ref.read(activeFindToggleProvider) != null;
    case NotoCommand.searchNotes:
      return true;
  }
}

/// Runs [command]. The menu entry and the shortcut both come through here, so
/// the two can never drift into doing different things.
Future<void> runNotoCommand(
  BuildContext context,
  WidgetRef ref,
  NotoCommand command,
) async {
  if (!canRunNotoCommand(ref, command)) return;
  final notes = ref.read(notesControllerProvider.notifier);
  final editor = ref.read(activeEditorProvider);
  final s = ref.read(appStringsProvider);

  void formatLine(Attribute attribute) {
    final current = editor!.getSelectionStyle().attributes[attribute.key];
    editor.formatSelection(
      current?.value == attribute.value ? Attribute.clone(attribute, null) : attribute,
    );
  }

  switch (command) {
    case NotoCommand.newNote:
      await notes.createNote();
    case NotoCommand.importNote:
      await notes.importNoteFromFile();
    case NotoCommand.save:
      await notes.saveSelected();
    case NotoCommand.saveAs:
      await notes.exportSelected();
    case NotoCommand.attach:
      await notes.attachDocument();
    case NotoCommand.moveToTrash:
      await notes.moveSelectedToTrash();
    case NotoCommand.quit:
      await SystemNavigator.pop();
    case NotoCommand.toggleTrash:
      notes.toggleTrash();
    case NotoCommand.toggleToolbar:
      await ref.read(toolbarVisibleProvider.notifier).toggle();
    case NotoCommand.embedImages:
      await ref.read(embedImagesProvider.notifier).toggle();
    case NotoCommand.toggleSidebar:
      final sidebar = ref.read(sidebarVisibleProvider.notifier);
      sidebar.state = !sidebar.state;
    case NotoCommand.cycleTheme:
      await ref.read(themeChoiceProvider.notifier).cycle();
    case NotoCommand.toggleLanguage:
      await ref.read(localeControllerProvider.notifier).toggleEnglishSpanish();
    case NotoCommand.undo:
      editor!.undo();
    case NotoCommand.redo:
      editor!.redo();
    case NotoCommand.find:
      ref.read(activeFindToggleProvider)?.call();
    case NotoCommand.searchNotes:
      ref.read(notesSearchFocusProvider).requestFocus();
    case NotoCommand.bold:
      formatLine(Attribute.bold);
    case NotoCommand.italic:
      formatLine(Attribute.italic);
    case NotoCommand.underline:
      formatLine(Attribute.underline);
    case NotoCommand.heading1:
      formatLine(Attribute.h1);
    case NotoCommand.heading2:
      formatLine(Attribute.h2);
    case NotoCommand.heading3:
      formatLine(Attribute.h3);
    case NotoCommand.shortcutsGuide:
      if (context.mounted) await showShortcutsDialog(context, s);
    case NotoCommand.about:
      if (context.mounted) showNotoAboutDialog(context, ref);
  }
}

/// Shortcut bindings for every command that has one, straight from the table.
Map<ShortcutActivator, Intent> notoShortcuts() {
  return {
    for (final command in NotoCommand.values)
      if (command.shortcut != null)
        command.shortcut!: NotoCommandIntent(command),
  };
}

/// A tick beside the options that are either on or off, so their state is
/// visible without opening anything.
Widget? _checkmarkFor(WidgetRef ref, NotoCommand command) {
  final on = switch (command) {
    NotoCommand.toggleToolbar => ref.watch(toolbarVisibleProvider),
    NotoCommand.embedImages => ref.watch(embedImagesProvider),
    _ => null,
  };
  if (on == null) return null;
  return Icon(on ? Icons.check_rounded : null, size: 18);
}

/// The menu bar: File, Edit, View, Format, Help.
class NotoMenuBar extends ConsumerWidget {
  const NotoMenuBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    // Rebuild when either changes, so entries enable and disable as you work.
    ref.watch(notesControllerProvider);
    ref.watch(activeEditorProvider);

    return MenuBar(
      style: const MenuStyle(
        elevation: WidgetStatePropertyAll(0),
        backgroundColor: WidgetStatePropertyAll(Colors.transparent),
        padding: WidgetStatePropertyAll(EdgeInsets.zero),
      ),
      children: [
        for (final menu in NotoMenu.values)
          SubmenuButton(
            menuChildren: [
              for (final command in NotoCommand.inMenu(menu))
                MenuItemButton(
                  leadingIcon: _checkmarkFor(ref, command),
                  shortcut: command.shortcut,
                  onPressed: canRunNotoCommand(ref, command)
                      ? () => runNotoCommand(context, ref, command)
                      : null,
                  child: Text(command.label(s)),
                ),
            ],
            child: Text(menu.label(s)),
          ),
      ],
    );
  }
}
