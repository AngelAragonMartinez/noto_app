import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../app/app_metadata.dart';
import '../../app/app_strings.dart';
import '../../app/document_logo.dart';

Future<void> showNotoAboutDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => const _NotoAboutDialog(),
  );
}

class _NotoAboutDialog extends ConsumerWidget {
  const _NotoAboutDialog();

  Future<void> _openUrl(String url) async {
    try {
      await Process.start(
        'xdg-open',
        [url],
        mode: ProcessStartMode.detached,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final s = ref.watch(appStringsProvider);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: DocumentLogo(
                  size: 56,
                  color: colors.onSurface,
                  background: colors.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                kAppName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${s.aboutVersionLine} $kAppVersion',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                s.aboutTagline,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  letterSpacing: -0.1,
                  color: colors.onSurfaceVariant.withValues(alpha: 0.92),
                ),
              ),
              if (kProjectRepositoryUrl.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _openUrl(kProjectRepositoryUrl.trim()),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FaIcon(
                            FontAwesomeIcons.github,
                            size: 20,
                            color: colors.onSurface,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              s.aboutSourceCode,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: colors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Text(
                s.aboutCreatedBy,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _openUrl(kGithubProfileUrl),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FaIcon(
                          FontAwesomeIcons.github,
                          size: 20,
                          color: colors.onSurface,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          kGithubUsername,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: colors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Divider(height: 1, color: colors.outlineVariant),
              const SizedBox(height: 14),
              Text(
                s.aboutLicenseLabel,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.2,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                kLicenseName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                kLicenseCopyright,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.35,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(s.aboutClose),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
