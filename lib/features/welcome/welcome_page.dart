import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_strings.dart';
import '../../app/document_logo.dart';
import '../../app/locale_controller.dart';
import 'welcome_controller.dart';

class WelcomePage extends ConsumerWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final s = ref.watch(appStringsProvider);
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                tooltip: s.languageTooltip,
                onPressed: () => ref
                    .read(localeControllerProvider.notifier)
                    .toggleEnglishSpanish(),
                icon: const Icon(Icons.translate_rounded),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final maxH = constraints.maxHeight;
                    final safeMaxH = maxH.isFinite && maxH > 16
                        ? maxH - 4
                        : double.infinity;
                    return FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: 480,
                          maxHeight: safeMaxH,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            DocumentLogo(
                              size: 84,
                              color: colors.onSurface,
                              background: colors.surfaceContainerHighest,
                            ),
                            const SizedBox(height: 22),
                            Text(
                              s.welcomeTitle,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.55,
                                color: colors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              s.welcomeSubtitle,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13.5,
                                height: 1.38,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 22),
                            _Bullet(
                              icon: Icons.lock_outline,
                              text: s.welcomeBulletVault,
                            ),
                            const _BulletGap(),
                            _Bullet(
                              icon: Icons.edit_note_outlined,
                              text: s.welcomeBulletEditor,
                            ),
                            const _BulletGap(),
                            _Bullet(
                              icon: Icons.save_outlined,
                              text: s.welcomeBulletExport,
                            ),
                            const SizedBox(height: 20),
                            Divider(height: 1, color: colors.outlineVariant),
                            const SizedBox(height: 14),
                            Text.rich(
                              TextSpan(
                                style: TextStyle(
                                  fontSize: 12.75,
                                  height: 1.42,
                                  color: colors.onSurfaceVariant,
                                ),
                                children: [
                                  TextSpan(text: s.welcomeGuideHintBefore),
                                  TextSpan(
                                    text: s.userGuideNoteTitle,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: colors.onSurface,
                                      letterSpacing: -0.15,
                                    ),
                                  ),
                                  TextSpan(text: s.welcomeGuideHintAfter),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 22),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: () => ref
                                    .read(welcomeControllerProvider.notifier)
                                    .dismiss(),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                child: Text(
                                  s.welcomeContinue,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 17, color: colors.onSurfaceVariant),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              height: 1.38,
              color: colors.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

class _BulletGap extends StatelessWidget {
  const _BulletGap();
  @override
  Widget build(BuildContext context) => const SizedBox(height: 9);
}
