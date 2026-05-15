import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/notes/application/notes_controller.dart';
import '../features/notes/presentation/notes_home_page.dart';
import '../features/security/presentation/app_lock_gate.dart';
import '../features/welcome/welcome_controller.dart';
import '../features/welcome/welcome_page.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) =>
          const AppLockGate(child: _WelcomeOrHome()),
    ),
  ],
);

class _WelcomeOrHome extends ConsumerWidget {
  const _WelcomeOrHome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(notesControllerProvider);
    final status = ref.watch(welcomeControllerProvider);
    switch (status) {
      case WelcomeStatus.loading:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      case WelcomeStatus.show:
        return const WelcomePage();
      case WelcomeStatus.hide:
        return const NotesHomePage();
    }
  }
}
