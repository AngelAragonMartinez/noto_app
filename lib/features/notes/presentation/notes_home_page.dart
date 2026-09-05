import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:intl/intl.dart';

import '../../../app/app_strings.dart';
import '../../../app/document_logo.dart';
import '../../../app/locale_controller.dart';
import '../application/notes_controller.dart';
import '../data/note_export_repository.dart';
import '../../../app/ui_preferences.dart';
import '../../../app/theme_controller.dart';
import 'noto_commands.dart';
import 'noto_menu_bar.dart';
import '../domain/note.dart';
import '../domain/note_attachment.dart';
import 'local_image_embed_builder.dart';

enum UnsavedNoteChoice { save, discard, cancel }

Future<UnsavedNoteChoice?> showUnsavedNoteDialog(
  BuildContext context,
  WidgetRef ref,
) {
  final s = ref.read(appStringsProvider);
  return showDialog<UnsavedNoteChoice>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(s.saveChangesTitle),
        content: Text(s.saveChangesBody),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(UnsavedNoteChoice.cancel),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(UnsavedNoteChoice.discard),
            child: Text(s.dontSave),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(UnsavedNoteChoice.save),
            child: Text(s.save),
          ),
        ],
      );
    },
  );
}

Future<void> confirmCloseNoteAndRemoveFromNoto(
  BuildContext context,
  WidgetRef ref, {
  required bool narrow,
  required StateController<bool> sidebarController,
}) async {
  final cur = ref.read(notesControllerProvider).selectedNote;
  if (cur == null) {
    return;
  }
  if (!await confirmDiscardIfNeeded(context, ref, cur)) {
    return;
  }
  if (!context.mounted) {
    return;
  }
  final toRemove = ref.read(notesControllerProvider).selectedNote;
  if (toRemove == null) {
    if (narrow) {
      sidebarController.state = true;
    }
    return;
  }
  final s = ref.read(appStringsProvider);
  final displayTitle = toRemove.title.trim().isEmpty
      ? s.untitled
      : toRemove.title.trim();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(s.closeNoteConfirmTitle),
        content: Text(s.closeNoteConfirmBody(displayTitle)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(s.closeNoteConfirmAction),
          ),
        ],
      );
    },
  );
  if (confirmed != true || !context.mounted) {
    return;
  }
  await ref.read(notesControllerProvider.notifier).removeSelectedNoteFromApp();
  if (!context.mounted) {
    return;
  }
  if (narrow) {
    sidebarController.state = true;
  }
}

Future<bool> confirmDiscardIfNeeded(
  BuildContext context,
  WidgetRef ref,
  Note? current,
) async {
  if (current == null) {
    return true;
  }
  final ctrl = ref.read(notesControllerProvider.notifier);
  if (!ctrl.isNoteDirty(current)) {
    return true;
  }
  final choice = await showUnsavedNoteDialog(context, ref);
  if (!context.mounted) {
    return false;
  }
  if (choice == null || choice == UnsavedNoteChoice.cancel) {
    return false;
  }
  final latest = ref.read(notesControllerProvider).notes.firstWhere(
        (n) => n.id == current.id,
        orElse: () => current,
      );
  if (choice == UnsavedNoteChoice.save) {
    await ctrl.flushSave(latest);
  } else {
    await ctrl.revertToBaseline(latest);
  }
  return true;
}


class NotesHomePage extends ConsumerWidget {
  const NotesHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notesControllerProvider);
    final controller = ref.read(notesControllerProvider.notifier);
    final sidebarVisible = ref.watch(sidebarVisibleProvider);
    final sidebarController = ref.read(sidebarVisibleProvider.notifier);
    final colors = Theme.of(context).colorScheme;
    final s = ref.watch(appStringsProvider);

    return Scaffold(
      appBar: AppBar(
        // The panel toggle belongs beside the thing it opens, on the left.
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 4),
              child: DocumentLogo(
                size: 28,
                color: colors.onSurface,
                background: colors.surface,
              ),
            ),
            IconButton(
              tooltip: sidebarVisible ? s.hideSidebar : s.showSidebar,
              onPressed: () => sidebarController.state = !sidebarVisible,
              icon: Icon(
                sidebarVisible
                    ? Icons.menu_open_rounded
                    : Icons.view_sidebar_outlined,
              ),
            ),
          ],
        ),
        leadingWidth: 96,
        titleSpacing: 0,
        // The logo already says which app this is; the menus go where a
        // desktop app puts them, immediately after it.
        title: const NotoMenuBar(),
        // Word and LibreOffice keep the top strip to menus, not a row of
        // icons: everything that used to sit here now lives in a menu with
        // its shortcut written beside it. What is left needs a dialog of its
        // own before it can move.
        actions: [
          // Open, the startup lock and the note location moved into the menus,
          // where each shows what it does in words. They were the last three
          // icons whose meaning you had to already know.
          // Also in the menus with their shortcuts. The common ones stay
          // reachable in one click; what left were the three whose meaning you
          // had to already know.
          IconButton(
            tooltip: NotoCommand.toggleLanguage.label(s),
            onPressed: () => unawaited(
                runNotoCommand(context, ref, NotoCommand.toggleLanguage)),
            icon: const Icon(Icons.translate_rounded),
          ),
          IconButton(
            tooltip: switch (ref.watch(themeChoiceProvider)) {
              NotoTheme.system => s.themeTooltipSystem,
              NotoTheme.light => s.themeTooltipLight,
              NotoTheme.dark => s.themeTooltipDark,
              NotoTheme.byTime => s.themeTooltipByTime,
            },
            onPressed: () =>
                unawaited(runNotoCommand(context, ref, NotoCommand.cycleTheme)),
            icon: const Icon(Icons.brightness_6_outlined),
          ),
          IconButton(
            tooltip: NotoCommand.newNote.label(s),
            onPressed: canRunNotoCommand(ref, NotoCommand.newNote)
                ? () => unawaited(runNotoCommand(context, ref, NotoCommand.newNote))
                : null,
            icon: const Icon(Icons.edit_note_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (state.error != null) _Banner.error(message: state.error!),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SizeTransition(
                    sizeFactor: anim,
                    alignment: Alignment.topCenter,
                    child: child,
                  ),
                ),
                child: state.info == null
                    ? const SizedBox(
                        key: ValueKey('info-empty'),
                        width: double.infinity,
                      )
                    : _Banner.info(
                        key: ValueKey('info-${state.info}'),
                        message: state.info!,
                        dismissTooltip: s.dismissBanner,
                        onDismiss: () => ref
                            .read(notesControllerProvider.notifier)
                            .clearInfo(),
                      ),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 760;
                  // Narrow: list or editor; wide: can show both.
                  final showList = sidebarVisible;

                  Future<void> createAndFocus() async {
                    final cur =
                        ref.read(notesControllerProvider).selectedNote;
                    if (!await confirmDiscardIfNeeded(context, ref, cur)) {
                      return;
                    }
                    if (!context.mounted) return;
                    await controller.createNote();
                    if (narrow) sidebarController.state = false;
                  }

                  final listCloseNote =
                      (!state.showTrash && state.selectedNote != null)
                          ? () {
                              unawaited(
                                confirmCloseNoteAndRemoveFromNoto(
                                  context,
                                  ref,
                                  narrow: narrow,
                                  sidebarController: sidebarController,
                                ),
                              );
                            }
                          : null;

                  final list = _NotesList(
                    strings: s,
                    localeCode: ref.watch(localeControllerProvider).languageCode,
                    notes: state.notes,
                    selectedNoteId: state.selectedNote?.id,
                    isLoading: state.isLoading,
                    onSearch: controller.setQuery,
                    searchFocusNode: ref.watch(notesSearchFocusProvider),
                    onCloseNote: listCloseNote,
                    onSelect: (id) async {
                      final cur =
                          ref.read(notesControllerProvider).selectedNote;
                      if (cur != null && cur.id != id) {
                        if (!await confirmDiscardIfNeeded(
                          context,
                          ref,
                          cur,
                        )) {
                          return;
                        }
                      }
                      if (!context.mounted) return;
                      controller.select(id);
                      if (narrow) sidebarController.state = false;
                    },
                    onCreate: createAndFocus,
                    showTrash: state.showTrash,
                    onChangeMode: (trash) async {
                      if (state.showTrash == trash) return;
                      final cur =
                          ref.read(notesControllerProvider).selectedNote;
                      if (!await confirmDiscardIfNeeded(context, ref, cur)) {
                        return;
                      }
                      if (!context.mounted) return;
                      controller.toggleTrash();
                    },
                  );

                  final editor = NoteEditorPane(
                    note: state.selectedNote,
                    showTrash: state.showTrash,
                    onChanged: controller.updateDraft,
                    onAttach: controller.attachDocument,
                    onExport: controller.exportSelected,
                    onQuickSave: controller.saveSelected,
                    onMoveToTrash: controller.moveSelectedToTrash,
                    onRestore: controller.restoreSelected,
                    onPermanentlyDelete: controller.permanentlyDeleteSelected,
                    onCreate: createAndFocus,
                    onBack: narrow
                        ? () {
                            unawaited(() async {
                              final cur = ref
                                  .read(notesControllerProvider)
                                  .selectedNote;
                              if (!await confirmDiscardIfNeeded(
                                context,
                                ref,
                                cur,
                              )) {
                                return;
                              }
                              if (!context.mounted) return;
                              sidebarController.state = true;
                            }());
                          }
                        : null,
                  );

                  if (narrow) {
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: showList
                          ? KeyedSubtree(
                              key: const ValueKey('list'),
                              child: list,
                            )
                          : KeyedSubtree(
                              key: const ValueKey('editor'),
                              child: editor,
                            ),
                    );
                  }

                  return Row(
                    children: [
                      if (showList) ...[
                        SizedBox(width: 320, child: list),
                        Container(width: 1, color: colors.outline),
                      ],
                      Expanded(child: editor),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}




class _Banner extends StatelessWidget {
  const _Banner({
    super.key,
    required this.message,
    required this.isError,
    this.dismissTooltip,
    this.onDismiss,
  });

  factory _Banner.error({Key? key, required String message}) =>
      _Banner(key: key, message: message, isError: true);

  factory _Banner.info({
    Key? key,
    required String message,
    required String dismissTooltip,
    VoidCallback? onDismiss,
  }) =>
      _Banner(
        key: key,
        message: message,
        isError: false,
        dismissTooltip: dismissTooltip,
        onDismiss: onDismiss,
      );

  final String message;
  final bool isError;
  final String? dismissTooltip;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bg = isError
        ? const Color(0x14B00020)
        : colors.surfaceContainerHighest;
    final fg = isError ? const Color(0xFFB00020) : colors.onSurface;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: colors.outline)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SelectableText(
              message,
              style: TextStyle(color: fg, fontSize: 12.5),
            ),
          ),
          if (onDismiss != null && !isError)
            IconButton(
              tooltip: dismissTooltip,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
              icon: Icon(Icons.close_rounded, size: 18, color: fg),
              onPressed: onDismiss,
            ),
        ],
      ),
    );
  }
}

class _NotesList extends StatelessWidget {
  const _NotesList({
    required this.strings,
    required this.localeCode,
    required this.notes,
    required this.selectedNoteId,
    required this.isLoading,
    required this.onSearch,
    required this.searchFocusNode,
    this.onCloseNote,
    required this.onSelect,
    required this.onCreate,
    required this.showTrash,
    required this.onChangeMode,
  });

  final AppStrings strings;
  final String localeCode;
  final List<Note> notes;
  final String? selectedNoteId;
  final bool isLoading;
  final ValueChanged<String> onSearch;
  final FocusNode searchFocusNode;
  final VoidCallback? onCloseNote;
  final Future<void> Function(String id) onSelect;
  final Future<void> Function() onCreate;
  final bool showTrash;
  final Future<void> Function(bool trash) onChangeMode;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      color: colors.surfaceContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: _SegmentedSwitch(
              showTrash: showTrash,
              notesLabel: strings.notesTab,
              trashLabel: strings.trashTab,
              onChange: onChangeMode,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: TextField(
              decoration: InputDecoration(
                hintText: strings.search,
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                isDense: true,
              ),
              focusNode: searchFocusNode,
              onChanged: onSearch,
            ),
          ),
          SizedBox(
            height: 2,
            child: isLoading ? const LinearProgressIndicator() : null,
          ),
          Expanded(
            child: notes.isEmpty
                ? _EmptyList(
                    showTrash: showTrash,
                    strings: strings,
                    onCreate: onCreate,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    itemCount: notes.length,
                    itemBuilder: (context, index) {
                      final note = notes[index];
                      return _NoteTile(
                        note: note,
                        strings: strings,
                        localeCode: localeCode,
                        selected: selectedNoteId == note.id,
                        onClose: !showTrash &&
                                selectedNoteId == note.id &&
                                onCloseNote != null
                            ? onCloseNote
                            : null,
                        onTap: () {
                          unawaited(onSelect(note.id));
                        },
                      );
                    },
                  ),
          ),
          if (!showTrash)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              child: FilledButton.icon(
                onPressed: () {
                  unawaited(onCreate());
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(strings.newNote),
              ),
            ),
        ],
      ),
    );
  }
}

class _SegmentedSwitch extends StatelessWidget {
  const _SegmentedSwitch({
    required this.showTrash,
    required this.notesLabel,
    required this.trashLabel,
    required this.onChange,
  });

  final bool showTrash;
  final String notesLabel;
  final String trashLabel;
  final Future<void> Function(bool showTrash) onChange;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.outline),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          Expanded(
            child: _SegmentTab(
              icon: Icons.description_outlined,
              label: notesLabel,
              selected: !showTrash,
              onTap: () {
                unawaited(onChange(false));
              },
            ),
          ),
          Expanded(
            child: _SegmentTab(
              icon: Icons.delete_outline,
              label: trashLabel,
              selected: showTrash,
              onTap: () {
                unawaited(onChange(true));
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentTab extends StatelessWidget {
  const _SegmentTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: selected ? colors.surfaceContainerHighest : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: selected
                      ? colors.onSurface
                      : colors.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected
                        ? colors.onSurface
                        : colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyList extends StatelessWidget {
  const _EmptyList({
    required this.showTrash,
    required this.strings,
    required this.onCreate,
  });

  final bool showTrash;
  final AppStrings strings;
  final Future<void> Function() onCreate;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              showTrash ? Icons.delete_outline : Icons.description_outlined,
              size: 30,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              showTrash ? strings.trashEmpty : strings.noNotesYet,
              style: TextStyle(
                color: colors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              showTrash ? strings.trashEmptyHint : strings.createFirstNote,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({
    required this.note,
    required this.strings,
    required this.localeCode,
    required this.selected,
    this.onClose,
    required this.onTap,
  });

  final Note note;
  final AppStrings strings;
  final String localeCode;
  final bool selected;
  final VoidCallback? onClose;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final date = DateFormat.MMMd(localeCode).add_Hm().format(note.updatedAt.toLocal());
    final title =
        note.title.trim().isEmpty ? strings.untitled : note.title;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: selected ? colors.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? colors.outline : Colors.transparent,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                    if (note.attachments.isNotEmpty)
                      Icon(
                        Icons.attach_file_rounded,
                        size: 14,
                        color: colors.onSurfaceVariant,
                      ),
                    if (onClose != null) ...[
                      const SizedBox(width: 2),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        tooltip: strings.closeNoteListTooltip,
                        onPressed: onClose,
                        icon: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '$date  ·  ${notePreviewLine(note, strings)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Heading style for the editor, carrying size and weight but no colour.
///
/// The built-in heading styles pin a colour, and a pinned colour wins over the
/// colour attribute sitting on the text itself. Colouring or highlighting a
/// title therefore did nothing on screen, even though the attribute was stored
/// and exported correctly the whole time. Leaving colour unset here gives the
/// text's own attribute nothing to fight.
@visibleForTesting
DefaultTextBlockStyle notoHeadingStyle(double fontSize) {
  return DefaultTextBlockStyle(
    TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      height: 1.25,
      letterSpacing: -0.3,
      decoration: TextDecoration.none,
    ),
    const HorizontalSpacing(0, 0),
    const VerticalSpacing(16, 4),
    const VerticalSpacing(0, 0),
    null,
  );
}

class NoteEditorPane extends ConsumerStatefulWidget {
  const NoteEditorPane({
    required this.note,
    required this.showTrash,
    required this.onChanged,
    required this.onAttach,
    required this.onExport,
    required this.onQuickSave,
    required this.onMoveToTrash,
    required this.onRestore,
    required this.onPermanentlyDelete,
    required this.onCreate,
    required this.onBack,
    super.key,
  });

  final Note? note;
  final bool showTrash;
  final void Function(
    Note note, {
    String? title,
    String? body,
    List<String>? tags,
  }) onChanged;
  final Future<void> Function() onAttach;
  final Future<void> Function({NoteExportFormat? preferredFormat}) onExport;
  final Future<void> Function() onQuickSave;
  final Future<void> Function() onMoveToTrash;
  final Future<void> Function() onRestore;
  final Future<void> Function() onPermanentlyDelete;
  final Future<void> Function() onCreate;
  final VoidCallback? onBack;

  @override
  ConsumerState<NoteEditorPane> createState() => _NoteEditorPaneState();
}

class _NoteEditorPaneState extends ConsumerState<NoteEditorPane> {
  final _titleController = TextEditingController();
  final _tagsController = TextEditingController();
  final _titleFocus = FocusNode();
  final _tagsFocus = FocusNode();
  final _editorFocus = FocusNode();
  final _editorScroll = ScrollController();
  final _findController = TextEditingController();
  final _replaceController = TextEditingController();
  final _findFocus = FocusNode();
  late QuillController _quillController;
  String? _loadedNoteId;
  DateTime? _loadedNoteUpdatedAt;
  DefaultStyles? _cachedStyles;
  Brightness? _cachedStylesBrightness;

  bool _findVisible = false;
  bool _showReplace = false;
  bool _caseSensitive = false;
  List<int> _matchOffsets = const [];
  int _currentMatchIndex = -1;

  @override
  void initState() {
    super.initState();
    _quillController = QuillController.basic(config: _buildQuillConfig());
    _quillController.addListener(_onQuillChanged);
    _syncControllers();
    // The Format menu sits far above this editor and has to reach the
    // document on screen. Publishing after the frame keeps it out of
    // the build that is still running.
    // Published straight away rather than a frame later: for that one frame
    // the Format menu had nothing to act on and drew itself greyed out.
    ref.read(activeEditorProvider.notifier).state = _quillController;
    ref.read(activeFindToggleProvider.notifier).state = _toggleFind;
  }

  QuillControllerConfig _buildQuillConfig() {
    return QuillControllerConfig(
      // ignore: experimental_member_use
      clipboardConfig: QuillClipboardConfig(
        // Off deliberately. With it on, pasting first goes through
        // quill_native_bridge_windows to look for HTML and Markdown on the
        // clipboard, and that path is where paste stops working in the note
        // body — while the title field, which uses Flutter's own clipboard,
        // keeps working. Turning it off routes the body down the same path as
        // the title.
        //
        // The cost is that content pasted from other applications arrives as
        // plain text rather than keeping its formatting. Paste working at all
        // is worth more than paste keeping formatting.
        // ignore: experimental_member_use
        enableExternalRichPaste: false,
        onImagePaste: (bytes) async {
          return ref.read(documentRepositoryProvider).storeInlineImageBytes(bytes);
        },
      ),
    );
  }

  Future<void> _insertImageFromToolbar() async {
    final note = widget.note;
    if (note == null || widget.showTrash) return;
    final path = await ref.read(documentRepositoryProvider).pickAndStoreInlineImage(
          imagesLabel: ref.read(appStringsProvider).insertImageTooltip,
        );
    if (path == null || !mounted) return;
    var insertAt = _quillController.selection.baseOffset;
    final len = _quillController.document.length;
    if (insertAt < 0) insertAt = 0;
    if (insertAt > len) insertAt = len;
    _quillController.document.insert(insertAt, BlockEmbed.image(path));
    _quillController.updateSelection(
      TextSelection.collapsed(offset: insertAt + 1),
      ChangeSource.local,
    );
  }

  @override
  void didUpdateWidget(covariant NoteEditorPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncControllers();
  }

  @override
  void dispose() {
    // Only if what is published is still mine. Flutter can mount the next
    // editor before disposing this one, and clearing unconditionally took
    // the new one down with it: the Format menu stayed grey with a note
    // open, and every shortcut that needs the editor did nothing.
    if (ref.read(activeEditorProvider) == _quillController) {
      ref.read(activeEditorProvider.notifier).state = null;
      ref.read(activeFindToggleProvider.notifier).state = null;
    }
    _quillController.removeListener(_onQuillChanged);
    _quillController.dispose();
    _titleController.dispose();
    _tagsController.dispose();
    _titleFocus.dispose();
    _tagsFocus.dispose();
    _editorFocus.dispose();
    _editorScroll.dispose();
    _findController.dispose();
    _replaceController.dispose();
    _findFocus.dispose();
    super.dispose();
  }

  void _toggleFind() {
    setState(() {
      _findVisible = !_findVisible;
      if (!_findVisible) {
        _showReplace = false;
        _matchOffsets = const [];
        _currentMatchIndex = -1;
      }
    });
    if (_findVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _findFocus.requestFocus();
        _findController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _findController.text.length,
        );
      });
    }
  }

  void _computeMatches() {
    final query = _findController.text;
    if (query.isEmpty) {
      setState(() {
        _matchOffsets = const [];
        _currentMatchIndex = -1;
      });
      return;
    }
    final text = _quillController.document.toPlainText();
    final source = _caseSensitive ? text : text.toLowerCase();
    final needle = _caseSensitive ? query : query.toLowerCase();
    final results = <int>[];
    var idx = 0;
    while (true) {
      final found = source.indexOf(needle, idx);
      if (found < 0) break;
      results.add(found);
      idx = found + (needle.isEmpty ? 1 : needle.length);
    }
    setState(() {
      _matchOffsets = results;
      _currentMatchIndex = results.isEmpty ? -1 : 0;
    });
    if (results.isNotEmpty) _selectMatch(0);
  }

  void _selectMatch(int idx) {
    if (idx < 0 || idx >= _matchOffsets.length) return;
    final offset = _matchOffsets[idx];
    final len = _findController.text.length;
    _quillController.updateSelection(
      TextSelection(baseOffset: offset, extentOffset: offset + len),
      ChangeSource.local,
    );
    setState(() => _currentMatchIndex = idx);
  }

  void _nextMatch() {
    if (_matchOffsets.isEmpty) return;
    final next = (_currentMatchIndex + 1) % _matchOffsets.length;
    _selectMatch(next);
  }

  void _prevMatch() {
    if (_matchOffsets.isEmpty) return;
    final prev =
        (_currentMatchIndex - 1 + _matchOffsets.length) % _matchOffsets.length;
    _selectMatch(prev);
  }

  void _replaceCurrent() {
    if (_currentMatchIndex < 0 ||
        _currentMatchIndex >= _matchOffsets.length) {
      return;
    }
    final offset = _matchOffsets[_currentMatchIndex];
    final len = _findController.text.length;
    final replacement = _replaceController.text;
    _quillController.replaceText(
      offset,
      len,
      replacement,
      TextSelection.collapsed(offset: offset + replacement.length),
    );
    _computeMatches();
  }

  void _replaceAll() {
    final query = _findController.text;
    if (query.isEmpty) return;
    final replacement = _replaceController.text;
    _computeMatches();
    if (_matchOffsets.isEmpty) return;
    final offsets = List<int>.from(_matchOffsets);
    for (final offset in offsets.reversed) {
      _quillController.replaceText(
        offset,
        query.length,
        replacement,
        TextSelection.collapsed(offset: offset + replacement.length),
      );
    }
    _computeMatches();
  }

  Document _documentFromBody(String body) {
    if (body.trim().isEmpty) {
      return Document();
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is List) {
        return Document.fromJson(decoded);
      }
    } catch (_) {}
    final doc = Document();
    doc.insert(0, body);
    return doc;
  }

  /// Sets controller text without selecting-all (assigning [TextEditingController.text]
  /// re-applies text on GTK/Linux and often selects the whole field).
  void _setTitleControllerText(String text) {
    if (_titleController.text == text) return;
    _titleController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
      composing: TextRange.empty,
    );
  }

  void _setTagsControllerText(String text) {
    if (_tagsController.text == text) return;
    _tagsController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
      composing: TextRange.empty,
    );
  }

  void _syncControllers() {
    final note = widget.note;
    if (note == null) {
      _loadedNoteId = null;
      _loadedNoteUpdatedAt = null;
      _titleController.clear();
      _tagsController.clear();
      _replaceQuillController(QuillController.basic(config: _buildQuillConfig()));
      return;
    }
    if (note.id == _loadedNoteId &&
        note.updatedAt == _loadedNoteUpdatedAt) {
      return;
    }

    final switchingNote = note.id != _loadedNoteId;
    if (switchingNote) {
      _loadedNoteId = note.id;
      _loadedNoteUpdatedAt = note.updatedAt;
      _setTitleControllerText(note.title);
      _setTagsControllerText(note.tags.join(', '));
      final doc = _documentFromBody(note.body);
      _replaceQuillController(
        QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
          config: _buildQuillConfig(),
        ),
      );
      _quillController.readOnly = widget.showTrash;
      return;
    }

    // Same note: `updatedAt` changed after save — only push remote text/body
    // when it differs from the widgets so we don't clobber IME or selection.
    _loadedNoteUpdatedAt = note.updatedAt;
    _setTitleControllerText(note.title);
    _setTagsControllerText(note.tags.join(', '));
    final encoded =
        jsonEncode(_quillController.document.toDelta().toJson());
    if (encoded != note.body) {
      final doc = _documentFromBody(note.body);
      _replaceQuillController(
        QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
          config: _buildQuillConfig(),
        ),
      );
    }
    _quillController.readOnly = widget.showTrash;
  }

  void _replaceQuillController(QuillController next) {
    _quillController.removeListener(_onQuillChanged);
    _quillController.dispose();
    _quillController = next;
    _quillController.addListener(_onQuillChanged);
  }

  void _onQuillChanged() {
    final note = widget.note;
    if (note == null) return;
    if (widget.showTrash) return;
    final delta = _quillController.document.toDelta();
    final encoded = jsonEncode(delta.toJson());
    if (encoded == note.body) return;
    widget.onChanged(note, body: encoded);
  }

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    if (note == null) {
      return _EmptyEditor(onCreate: widget.onCreate);
    }

    _quillController.readOnly = widget.showTrash;

    final colors = Theme.of(context).colorScheme;
    final s = ref.watch(appStringsProvider);
    final lang = ref.watch(localeControllerProvider).languageCode;
    final date =
        DateFormat.yMMMMd(lang).add_Hm().format(note.updatedAt.toLocal());

    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            const _ToggleFindIntent(),
        const SingleActivator(LogicalKeyboardKey.escape):
            const _CloseFindIntent(),
        const SingleActivator(LogicalKeyboardKey.tab): const NextFocusIntent(),
        const SingleActivator(LogicalKeyboardKey.tab, shift: true):
            const PreviousFocusIntent(),
        const SingleActivator(LogicalKeyboardKey.keyC, control: true):
            CopySelectionTextIntent.copy,
        const SingleActivator(LogicalKeyboardKey.keyX, control: true):
            const CopySelectionTextIntent.cut(SelectionChangedCause.keyboard),
        const SingleActivator(LogicalKeyboardKey.keyV, control: true):
            const PasteTextIntent(SelectionChangedCause.keyboard),
        const SingleActivator(LogicalKeyboardKey.keyA, control: true):
            const SelectAllTextIntent(SelectionChangedCause.keyboard),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _ToggleFindIntent: CallbackAction<_ToggleFindIntent>(
            onInvoke: (_) {
              _toggleFind();
              return null;
            },
          ),
          _CloseFindIntent: CallbackAction<_CloseFindIntent>(
            onInvoke: (_) {
              if (_findVisible) _toggleFind();
              return null;
            },
          ),
        },
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EditorToolbar(
          strings: s,
          showTrash: widget.showTrash,
          quickSaveLabel: s.save,
          canQuickSave: note.lastExportPath != null,
          onAttach: widget.onAttach,
          onExport: widget.onExport,
          onQuickSave: widget.onQuickSave,
          onToggleFind: _toggleFind,
          onMoveToTrash: widget.onMoveToTrash,
          onRestore: widget.onRestore,
          onPermanentlyDelete: widget.onPermanentlyDelete,
          onBack: widget.onBack,
        ),
        const Divider(height: 1),
        if (!widget.showTrash && ref.watch(toolbarVisibleProvider)) ...[
          _QuillToolbar(
            controller: _quillController,
            onInsertImage: _insertImageFromToolbar,
            insertImageTooltip: s.insertImageTooltip,
          ),
          const Divider(height: 1),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: _findVisible
                ? _FindReplaceBar(
                    strings: s,
                    findController: _findController,
                    replaceController: _replaceController,
                    findFocusNode: _findFocus,
                    matchCount: _matchOffsets.length,
                    currentIndex: _currentMatchIndex,
                    caseSensitive: _caseSensitive,
                    showReplace: _showReplace,
                    onChanged: _computeMatches,
                    onToggleCase: () {
                      setState(() => _caseSensitive = !_caseSensitive);
                      _computeMatches();
                    },
                    onToggleReplace: () =>
                        setState(() => _showReplace = !_showReplace),
                    onPrev: _prevMatch,
                    onNext: _nextMatch,
                    onReplace: _replaceCurrent,
                    onReplaceAll: _replaceAll,
                    onClose: _toggleFind,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
        Expanded(
          child: Center(
            child: ConstrainedBox(
              // Wider once the side panel is hidden. Hiding the panel is a
              // request for more room to write, so the text takes some of it
              // rather than leaving a narrow column adrift in the middle of a
              // wide window. Still capped: a line running the full width of a
              // large monitor is tiring to read, which is why the limit exists
              // at all.
              constraints: BoxConstraints(
                maxWidth: ref.watch(sidebarVisibleProvider) ? 820 : 1100,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 22, 28, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _titleController,
                      focusNode: _titleFocus,
                      readOnly: widget.showTrash,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => _tagsFocus.requestFocus(),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                      decoration: InputDecoration(
                        hintText: s.titleHint,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (value) =>
                          widget.onChanged(note, title: value),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          widget.showTrash
                              ? Icons.delete_outline
                              : Icons.schedule_outlined,
                          size: 13,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.showTrash
                              ? '${s.inTrashLine} $date'
                              : '${s.updatedPrefix} $date',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _tagsController,
                      focusNode: _tagsFocus,
                      readOnly: widget.showTrash,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => _editorFocus.requestFocus(),
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: s.tagsHint,
                        prefixIcon: Icon(Icons.tag_rounded, size: 16),
                        isDense: true,
                      ),
                      onChanged: (value) =>
                          widget.onChanged(note, tags: _parseTags(value)),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: QuillEditor(
                        controller: _quillController,
                        focusNode: _editorFocus,
                        scrollController: _editorScroll,
                        config: QuillEditorConfig(
                          placeholder: s.editorPlaceholder,
                          padding: EdgeInsets.zero,
                          autoFocus: false,
                          expands: true,
                          scrollable: true,
                          customStyles: _buildEditorStyles(context),
                          embedBuilders: [
                            LocalFileImageEmbedBuilder(
                              documents:
                                  ref.read(documentRepositoryProvider),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (note.attachments.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      Text(
                        s.attachments,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurfaceVariant,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final attachment in note.attachments)
                            _AttachmentChip(
                              strings: s,
                              attachment: attachment,
                              onOpen: () => ref
                                  .read(notesControllerProvider.notifier)
                                  .openAttachment(attachment),
                              onDelete: () => _confirmRemoveAttachment(
                                context,
                                ref,
                                attachment,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
      ),
    );
  }

  List<String> _parseTags(String value) {
    return value
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList();
  }

  Future<void> _confirmRemoveAttachment(
    BuildContext context,
    WidgetRef ref,
    NoteAttachment attachment,
  ) async {
    final s = ref.read(appStringsProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(s.removeAttachmentTitle),
          content: Text(
            s.removeAttachmentBody(attachment.originalName),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(s.cancel),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(s.remove),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await ref
          .read(notesControllerProvider.notifier)
          .removeAttachment(attachment);
    }
  }

  DefaultStyles _buildEditorStyles(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    if (_cachedStyles != null && _cachedStylesBrightness == brightness) {
      return _cachedStyles!;
    }
    final isDark = brightness == Brightness.dark;
    final codeBg =
        isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF6F8FA);
    final codeBorder =
        isDark ? const Color(0xFF2D2D30) : const Color(0xFFE5E7EB);
    final codeText =
        isDark ? const Color(0xFFD4D4D4) : const Color(0xFF1F2328);
    final inlineCodeBg = isDark
        ? const Color(0xFF2D2D30)
        : const Color(0xFFEFF1F4);

    final codeTextStyle = TextStyle(
      fontFamily: 'monospace',
      fontFamilyFallback: const [
        'JetBrains Mono',
        'Fira Code',
        'Cascadia Code',
        'Menlo',
        'Consolas',
        'DejaVu Sans Mono',
      ],
      fontSize: 13.5,
      height: 1.5,
      color: codeText,
    );

    final styles = DefaultStyles(
      h1: notoHeadingStyle(30),
      h2: notoHeadingStyle(24),
      h3: notoHeadingStyle(20),
      code: DefaultTextBlockStyle(
        codeTextStyle,
        const HorizontalSpacing(12, 12),
        const VerticalSpacing(10, 10),
        const VerticalSpacing(0, 0),
        BoxDecoration(
          color: codeBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: codeBorder),
        ),
      ),
      inlineCode: InlineCodeStyle(
        style: codeTextStyle.copyWith(fontSize: 13),
        backgroundColor: inlineCodeBg,
        radius: const Radius.circular(4),
      ),
    );
    _cachedStyles = styles;
    _cachedStylesBrightness = brightness;
    return styles;
  }
}

class _ToggleFindIntent extends Intent {
  const _ToggleFindIntent();
}

class _CloseFindIntent extends Intent {
  const _CloseFindIntent();
}

class _QuillToolbar extends ConsumerWidget {
  const _QuillToolbar({
    required this.controller,
    this.onInsertImage,
    this.insertImageTooltip = '',
  });

  final QuillController controller;
  final Future<void> Function()? onInsertImage;
  final String insertImageTooltip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final selectedBg = colors.primary;
    final selectedFg = colors.onPrimary;
    final unselectedFg = colors.onSurface;
    final s = ref.watch(appStringsProvider);
    return Container(
      color: colors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        children: [
          if (onInsertImage != null)
            IconButton(
              tooltip: insertImageTooltip,
              icon: const Icon(Icons.image_outlined, size: 22),
              onPressed: () {
                unawaited(onInsertImage!());
              },
            ),
          _HistoryIconButton(
            controller: controller,
            isUndo: true,
            tooltip: s.undoTooltip,
          ),
          _HistoryIconButton(
            controller: controller,
            isUndo: false,
            tooltip: s.redoTooltip,
          ),
          Expanded(
            child: QuillSimpleToolbar(
              controller: controller,
              config: QuillSimpleToolbarConfig(
                multiRowsDisplay: false,
                showUndo: false,
                showRedo: false,
                showFontFamily: false,
                showFontSize: false,
                showLineHeightButton: true,
                showSubscript: false,
                showSuperscript: false,
                showSmallButton: false,
                showSearchButton: false,
                showAlignmentButtons: true,
                showDirection: false,
                showIndent: true,
                // ignore: experimental_member_use
                showClipboardCopy: false,
                // ignore: experimental_member_use
                showClipboardCut: false,
                // ignore: experimental_member_use
                showClipboardPaste: false,
                buttonOptions: QuillSimpleToolbarButtonOptions(
                  base: QuillToolbarBaseButtonOptions(
                    iconTheme: QuillIconTheme(
                      iconButtonSelectedData: IconButtonData(
                        color: selectedFg,
                        style: IconButton.styleFrom(
                          backgroundColor: selectedBg,
                          foregroundColor: selectedFg,
                        ),
                      ),
                      iconButtonUnselectedData: IconButtonData(
                        color: unselectedFg,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: unselectedFg,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Undo/redo button that reliably tracks controller state by listening to the
/// controller as a [ChangeNotifier] (rebuilds on every notifyListeners).
/// flutter_quill's bundled history button only subscribes to the changes
/// stream in initState, so it can miss updates when the controller is swapped.
class _HistoryIconButton extends StatelessWidget {
  const _HistoryIconButton({
    required this.controller,
    required this.isUndo,
    required this.tooltip,
  });

  final QuillController controller;
  final bool isUndo;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final canPress = isUndo ? controller.hasUndo : controller.hasRedo;
        return IconButton(
          tooltip: tooltip,
          icon: Icon(
            isUndo ? Icons.undo_rounded : Icons.redo_rounded,
            size: 20,
          ),
          onPressed: canPress
              ? () {
                  if (isUndo) {
                    controller.undo();
                  } else {
                    controller.redo();
                  }
                }
              : null,
        );
      },
    );
  }
}

class _EditorToolbar extends StatelessWidget {
  const _EditorToolbar({
    required this.strings,
    required this.showTrash,
    required this.quickSaveLabel,
    required this.canQuickSave,
    required this.onAttach,
    required this.onExport,
    required this.onQuickSave,
    required this.onToggleFind,
    required this.onMoveToTrash,
    required this.onRestore,
    required this.onPermanentlyDelete,
    required this.onBack,
  });

  final AppStrings strings;
  final bool showTrash;
  final String quickSaveLabel;
  final bool canQuickSave;
  final Future<void> Function() onAttach;
  final Future<void> Function({NoteExportFormat? preferredFormat}) onExport;
  final Future<void> Function() onQuickSave;
  final VoidCallback onToggleFind;
  final Future<void> Function() onMoveToTrash;
  final Future<void> Function() onRestore;
  final Future<void> Function() onPermanentlyDelete;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      color: colors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              tooltip: strings.back,
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
            ),
          if (showTrash)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                strings.trashToolbar,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          // No Spacer: it pinned every action to the right edge and left a wide
          // empty band across the middle of the strip on a large window.
          const SizedBox(width: 8),
          if (!showTrash) ...[
            IconButton(
              tooltip: strings.findReplace,
              onPressed: onToggleFind,
              icon: const Icon(Icons.search_rounded, size: 20),
            ),
            // Attach, Save, Save as and Move to trash live in the File menu with
            // their shortcuts. Repeating them here only crowded the strip.
          ] else ...[
            _ToolbarButton(
              icon: Icons.restore_rounded,
              label: strings.restore,
              onPressed: onRestore,
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: strings.deleteForever,
              onPressed: onPermanentlyDelete,
              icon: const Icon(Icons.delete_forever_outlined, size: 20),
            ),
          ],
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () {
        onPressed();
      },
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }
}

class _EmptyEditor extends ConsumerWidget {
  const _EmptyEditor({required this.onCreate});

  final Future<void> Function() onCreate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final s = ref.watch(appStringsProvider);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DocumentLogo(
              size: 64,
              color: colors.onSurfaceVariant,
              background: colors.surfaceContainerHighest,
            ),
            const SizedBox(height: 18),
            Text(
              s.pickANote,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              s.pickANoteHint,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                unawaited(onCreate());
              },
              icon: const Icon(Icons.edit_note_rounded, size: 18),
              label: Text(s.newNote),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip({
    required this.strings,
    required this.attachment,
    required this.onOpen,
    required this.onDelete,
  });

  final AppStrings strings;
  final NoteAttachment attachment;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  Future<void> _showMenu(BuildContext context, Offset position) async {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        overlay.size.width - position.dx,
        overlay.size.height - position.dy,
      ),
      items: [
        PopupMenuItem<String>(
          value: 'open',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.open_in_new, size: 18),
            title: Text(strings.openAttachment),
          ),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.delete_outline, size: 18),
            title: Text(strings.removeAttachmentAction),
          ),
        ),
      ],
    );
    if (selected == 'open') {
      onOpen();
    } else if (selected == 'delete') {
      onDelete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapDown: (details) =>
          _showMenu(context, details.globalPosition),
      onLongPressStart: (details) =>
          _showMenu(context, details.globalPosition),
      child: ActionChip(
        avatar: const Icon(Icons.description_outlined, size: 16),
        label: Text(
          attachment.originalName,
          style: const TextStyle(fontSize: 12),
        ),
        backgroundColor: colors.surfaceContainerHighest,
        side: BorderSide(color: colors.outline),
        tooltip: strings.attachmentChipTooltip,
        onPressed: onOpen,
      ),
    );
  }
}

class _FindReplaceBar extends StatelessWidget {
  const _FindReplaceBar({
    required this.strings,
    required this.findController,
    required this.replaceController,
    required this.findFocusNode,
    required this.matchCount,
    required this.currentIndex,
    required this.caseSensitive,
    required this.showReplace,
    required this.onChanged,
    required this.onToggleCase,
    required this.onToggleReplace,
    required this.onPrev,
    required this.onNext,
    required this.onReplace,
    required this.onReplaceAll,
    required this.onClose,
  });

  final AppStrings strings;
  final TextEditingController findController;
  final TextEditingController replaceController;
  final FocusNode findFocusNode;
  final int matchCount;
  final int currentIndex;
  final bool caseSensitive;
  final bool showReplace;
  final VoidCallback onChanged;
  final VoidCallback onToggleCase;
  final VoidCallback onToggleReplace;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onReplace;
  final VoidCallback onReplaceAll;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasMatches = matchCount > 0;
    final counter = matchCount == 0
        ? (findController.text.isEmpty ? '' : strings.noMatches)
        : '${currentIndex + 1} / $matchCount';

    return Container(
      color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip:
                    showReplace ? strings.findHideReplace : strings.findShowReplace,
                onPressed: onToggleReplace,
                icon: Icon(
                  showReplace
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.keyboard_arrow_right_rounded,
                  size: 18,
                ),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: TextField(
                  controller: findController,
                  focusNode: findFocusNode,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: strings.search,
                    prefixIcon: const Icon(Icons.search, size: 16),
                    isDense: true,
                    suffixText: counter.isEmpty ? null : counter,
                    suffixStyle: TextStyle(
                      fontSize: 11,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  onChanged: (_) => onChanged(),
                  onSubmitted: (_) => onNext(),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: strings.matchCase,
                onPressed: onToggleCase,
                icon: const Text(
                  'Aa',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                style: IconButton.styleFrom(
                  backgroundColor: caseSensitive
                      ? colors.primary.withValues(alpha: 0.15)
                      : null,
                  foregroundColor: caseSensitive
                      ? colors.primary
                      : colors.onSurfaceVariant,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  minimumSize: const Size(34, 34),
                ),
              ),
              IconButton(
                tooltip: strings.previousMatch,
                onPressed: hasMatches ? onPrev : null,
                icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 20),
              ),
              IconButton(
                tooltip: strings.nextMatch,
                onPressed: hasMatches ? onNext : null,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
              ),
              IconButton(
                tooltip: strings.closeFind,
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
            ],
          ),
          if (showReplace) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const SizedBox(width: 36),
                Expanded(
                  child: TextField(
                    controller: replaceController,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: strings.replaceWithHint,
                      prefixIcon: const Icon(Icons.swap_horiz_rounded, size: 16),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: hasMatches ? onReplace : null,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: Text(
                    strings.replace,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 6),
                FilledButton.tonal(
                  onPressed: hasMatches ? onReplaceAll : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: Text(
                    strings.replaceAll,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 40),
              ],
            ),
          ],
        ],
      ),
    );
  }
}



/// Turns the startup lock on and off.
///
/// Shown disabled, with an explanation, when the device has no Windows Hello
/// or equivalent — the lock cannot engage there, and a toggle that silently
/// does nothing is worse than one that says why.


/// Shows where the open note lives, in the same bar that confirms a save.
///
/// Pressing again clears it. The message is pinned rather than timed: a path
/// is there to be read and written down, which takes longer than the couple of
/// seconds a save confirmation needs.

