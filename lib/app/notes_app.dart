import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui' show AppExitResponse;

import 'app_router.dart';
import 'app_theme.dart';
import 'locale_controller.dart';
import 'theme_controller.dart';
import '../features/notes/application/notes_controller.dart';
import '../features/notes/presentation/noto_menu_bar.dart';
import '../features/notes/presentation/quit_save_dialog.dart';

class NotesApp extends ConsumerStatefulWidget {
  const NotesApp({super.key});

  @override
  ConsumerState<NotesApp> createState() => _NotesAppState();
}

class _NotesAppState extends ConsumerState<NotesApp>
    with WidgetsBindingObserver {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lifecycle = AppLifecycleListener(
      onExitRequested: _onExitRequested,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    setState(() {});
  }

  /// Removes the plaintext attachment copies opening an attachment leaves in
  /// the system temp directory.
  Future<void> _cleanUpDecryptedTempFiles() async {
    await ref.read(documentRepositoryProvider).cleanUpTempFiles();
  }

  Future<AppExitResponse> _onExitRequested() async {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) {
      await _cleanUpDecryptedTempFiles();
      return AppExitResponse.exit;
    }
    final notesState = ref.read(notesControllerProvider);
    final ctrl = ref.read(notesControllerProvider.notifier);
    final dirty =
        notesState.notes.where((n) => ctrl.isNoteDirty(n)).toList();
    if (dirty.isEmpty) {
      await _cleanUpDecryptedTempFiles();
      return AppExitResponse.exit;
    }

    final outcome = await showQuitUnsavedNotesDialog(
      ctx,
      dirtyNotes: dirty,
    );
    switch (outcome) {
      case QuitUnsavedOutcome.cancelled:
        return AppExitResponse.cancel;
      case QuitUnsavedOutcome.discardAndExit:
      case QuitUnsavedOutcome.savedAndExit:
        await _cleanUpDecryptedTempFiles();
        return AppExitResponse.exit;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Noto',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      locale: ref.watch(localeControllerProvider),
      // App-wide, so a shortcut works wherever the focus happens to be. Both
      // maps merge into the defaults instead of replacing them, which is what
      // passing them here would otherwise do: no more copy, paste or tab
      // traversal anywhere in the app.
      shortcuts: {
        ...WidgetsApp.defaultShortcuts,
        ...notoShortcuts(),
      },
      actions: {
        ...WidgetsApp.defaultActions,
        NotoCommandIntent: CallbackAction<NotoCommandIntent>(
          onInvoke: (intent) {
            final ctx = rootNavigatorKey.currentContext;
            if (ctx != null && ctx.mounted) {
              unawaited(runNotoCommand(ctx, ref, intent.command));
            }
            return null;
          },
        ),
      },
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('es'),
      ],
    );
  }
}
