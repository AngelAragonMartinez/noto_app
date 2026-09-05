import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_strings.dart';

/// The menus a command can live under, in the order they are shown.
enum NotoMenu { file, edit, view, format, help }

/// Every command Noto offers, with the menu it belongs to and its shortcut.
///
/// One table, three consumers: the menu bar, the shortcut bindings and the
/// keyboard guide are all built from it. Writing them separately is how a guide
/// ends up describing a shortcut that no longer exists, so there is nowhere here
/// for them to drift apart.
enum NotoCommand {
  // File
  newNote(NotoMenu.file, SingleActivator(LogicalKeyboardKey.keyN, control: true)),
  importNote(NotoMenu.file, SingleActivator(LogicalKeyboardKey.keyO, control: true)),
  save(NotoMenu.file, SingleActivator(LogicalKeyboardKey.keyS, control: true)),
  saveAs(NotoMenu.file,
      SingleActivator(LogicalKeyboardKey.keyS, control: true, shift: true)),
  attach(NotoMenu.file, SingleActivator(LogicalKeyboardKey.keyD, control: true)),
  moveToTrash(NotoMenu.file,
      SingleActivator(LogicalKeyboardKey.delete, control: true)),
  noteLocation(NotoMenu.file, null),
  quit(NotoMenu.file, SingleActivator(LogicalKeyboardKey.keyQ, control: true)),

  // Edit
  undo(NotoMenu.edit, SingleActivator(LogicalKeyboardKey.keyZ, control: true)),
  redo(NotoMenu.edit, SingleActivator(LogicalKeyboardKey.keyY, control: true)),
  find(NotoMenu.edit, SingleActivator(LogicalKeyboardKey.keyF, control: true)),
  searchNotes(NotoMenu.edit,
      SingleActivator(LogicalKeyboardKey.keyL, control: true)),

  // View
  toggleToolbar(NotoMenu.view,
      SingleActivator(LogicalKeyboardKey.f1, control: true)),
  toggleTrash(NotoMenu.view,
      SingleActivator(LogicalKeyboardKey.keyT, control: true, shift: true)),
  embedImages(NotoMenu.view, null),
  toggleSidebar(NotoMenu.view,
      SingleActivator(LogicalKeyboardKey.f9)),
  cycleTheme(NotoMenu.view, null),
  toggleLanguage(NotoMenu.view, null),
  appLock(NotoMenu.view, null),

  // Format
  bold(NotoMenu.format, SingleActivator(LogicalKeyboardKey.keyB, control: true)),
  italic(NotoMenu.format, SingleActivator(LogicalKeyboardKey.keyI, control: true)),
  underline(NotoMenu.format,
      SingleActivator(LogicalKeyboardKey.keyU, control: true)),
  heading1(NotoMenu.format,
      SingleActivator(LogicalKeyboardKey.digit1, control: true, alt: true)),
  heading2(NotoMenu.format,
      SingleActivator(LogicalKeyboardKey.digit2, control: true, alt: true)),
  heading3(NotoMenu.format,
      SingleActivator(LogicalKeyboardKey.digit3, control: true, alt: true)),

  // Help
  shortcutsGuide(NotoMenu.help, SingleActivator(LogicalKeyboardKey.f1)),
  about(NotoMenu.help, null),
  ;

  const NotoCommand(this.menu, this.shortcut);

  final NotoMenu menu;
  final SingleActivator? shortcut;

  static List<NotoCommand> inMenu(NotoMenu menu) =>
      values.where((c) => c.menu == menu).toList();
}

/// Human-readable name of the key combination, e.g. "Ctrl+Shift+S".
///
/// Built from the activator rather than written by hand beside it, so a
/// rebinding cannot leave the guide describing the old keys.
String shortcutLabel(SingleActivator activator) {
  final parts = <String>[
    if (activator.control) 'Ctrl',
    if (activator.alt) 'Alt',
    if (activator.shift) 'Shift',
    _keyLabel(activator.trigger),
  ];
  return parts.join('+');
}

String _keyLabel(LogicalKeyboardKey key) {
  if (key == LogicalKeyboardKey.delete) return 'Supr';
  if (key == LogicalKeyboardKey.f1) return 'F1';
  final label = key.keyLabel;
  return label.isEmpty ? key.debugName ?? '?' : label.toUpperCase();
}

extension NotoCommandLabel on NotoCommand {
  /// The command's name as shown in menus and in the guide.
  String label(AppStrings s) {
    switch (this) {
      case NotoCommand.newNote:
        return s.newNote;
      case NotoCommand.importNote:
        return s.menuImport;
      case NotoCommand.save:
        return s.save;
      case NotoCommand.saveAs:
        return s.saveAs;
      case NotoCommand.attach:
        return s.menuAttach;
      case NotoCommand.moveToTrash:
        return s.moveToTrash;
      case NotoCommand.noteLocation:
        return s.menuNoteLocation;
      case NotoCommand.appLock:
        return s.menuAppLock;
      case NotoCommand.quit:
        return s.menuQuit;
      case NotoCommand.undo:
        return s.undoTooltip;
      case NotoCommand.redo:
        return s.redoTooltip;
      case NotoCommand.find:
        return s.menuFind;
      case NotoCommand.searchNotes:
        return s.menuSearchNotes;
      case NotoCommand.toggleToolbar:
        return s.menuToggleToolbar;
      case NotoCommand.toggleTrash:
        return s.trashTab;
      case NotoCommand.embedImages:
        return s.menuEmbedImages;
      case NotoCommand.toggleSidebar:
        return s.menuSidebar;
      case NotoCommand.cycleTheme:
        return s.menuTheme;
      case NotoCommand.toggleLanguage:
        return s.languageTooltip;
      case NotoCommand.bold:
        return s.menuBold;
      case NotoCommand.italic:
        return s.menuItalic;
      case NotoCommand.underline:
        return s.menuUnderline;
      case NotoCommand.heading1:
        return s.menuHeading(1);
      case NotoCommand.heading2:
        return s.menuHeading(2);
      case NotoCommand.heading3:
        return s.menuHeading(3);
      case NotoCommand.shortcutsGuide:
        return s.menuShortcuts;
      case NotoCommand.about:
        return s.about;
    }
  }
}

extension NotoMenuLabel on NotoMenu {
  String label(AppStrings s) {
    switch (this) {
      case NotoMenu.file:
        return s.menuFile;
      case NotoMenu.edit:
        return s.menuEdit;
      case NotoMenu.view:
        return s.menuView;
      case NotoMenu.format:
        return s.menuFormat;
      case NotoMenu.help:
        return s.menuHelp;
    }
  }
}
