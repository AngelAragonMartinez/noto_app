import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_strings.dart';
import '../application/notes_controller.dart';
import '../domain/note.dart';

enum QuitUnsavedOutcome { cancelled, discardAndExit, savedAndExit }

Future<QuitUnsavedOutcome> showQuitUnsavedNotesDialog(
  BuildContext context, {
  required List<Note> dirtyNotes,
}) async {
  final result = await showDialog<QuitUnsavedOutcome>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _QuitUnsavedNotesDialog(dirtyNotes: dirtyNotes),
  );
  return result ?? QuitUnsavedOutcome.cancelled;
}

class _QuitUnsavedNotesDialog extends ConsumerStatefulWidget {
  const _QuitUnsavedNotesDialog({required this.dirtyNotes});

  final List<Note> dirtyNotes;

  @override
  ConsumerState<_QuitUnsavedNotesDialog> createState() =>
      _QuitUnsavedNotesDialogState();
}

class _QuitUnsavedNotesDialogState
    extends ConsumerState<_QuitUnsavedNotesDialog> {
  late Map<String, bool> _checked;

  @override
  void initState() {
    super.initState();
    _checked = {for (final n in widget.dirtyNotes) n.id: true};
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final colors = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(
        s.quitSaveTitle,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(s.quitSaveDescription),
              const SizedBox(height: 16),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    for (final n in widget.dirtyNotes)
                      CheckboxListTile(
                        value: _checked[n.id] ?? false,
                        onChanged: (v) =>
                            setState(() => _checked[n.id] = v ?? false),
                        title: Text(
                          n.title.trim().isEmpty ? s.untitled : n.title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          n.lastExportPath != null &&
                                  n.lastExportPath!.isNotEmpty
                              ? n.lastExportPath!
                              : s.noteOnlyInVaultSubtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context)
                        .pop(QuitUnsavedOutcome.cancelled),
                    child: Text(s.cancel),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: colors.error,
                      backgroundColor: colors.errorContainer
                          .withAlpha((255 * 0.35).round()),
                    ),
                    onPressed: () => Navigator.of(context)
                        .pop(QuitUnsavedOutcome.discardAndExit),
                    child: Text(s.discardChangesQuit),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () async {
                      final ctrl =
                          ref.read(notesControllerProvider.notifier);
                      for (final n in widget.dirtyNotes) {
                        final latest = ref
                            .read(notesControllerProvider)
                            .notes
                            .firstWhere(
                              (x) => x.id == n.id,
                              orElse: () => n,
                            );
                        if (_checked[n.id] == true) {
                          await ctrl.flushSave(latest);
                        } else {
                          await ctrl.revertToBaseline(latest);
                        }
                      }
                      if (context.mounted) {
                        Navigator.of(context)
                            .pop(QuitUnsavedOutcome.savedAndExit);
                      }
                    },
                    child: Text(s.save),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
