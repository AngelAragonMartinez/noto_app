import 'package:flutter/material.dart';

import '../../../app/app_strings.dart';
import 'noto_commands.dart';

/// Lists every command and the keys that trigger it.
///
/// Built by walking [NotoCommand], so it cannot fall behind: a command added to
/// the table appears here without anyone remembering to write it down, and a
/// rebinding shows the new keys because the label is derived from the activator
/// rather than typed beside it.
Future<void> showShortcutsDialog(BuildContext context, AppStrings s) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final colors = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        title: Text(s.shortcutsDialogTitle),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final menu in NotoMenu.values) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 14, bottom: 6),
                    child: Text(
                      menu.label(s),
                      style: Theme.of(dialogContext)
                          .textTheme
                          .labelLarge
                          ?.copyWith(color: colors.primary),
                    ),
                  ),
                  for (final command in NotoCommand.inMenu(menu))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Expanded(child: Text(command.label(s))),
                          if (command.shortcut != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colors.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(color: colors.outline),
                              ),
                              child: Text(
                                shortcutLabel(command.shortcut!),
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(s.aboutClose),
          ),
        ],
      );
    },
  );
}
