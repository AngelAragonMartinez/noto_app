import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/security_providers.dart';

class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate> {
  bool _unlocked = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _unlock();
  }

  Future<void> _unlock() async {
    final controller = ref.read(appLockControllerProvider);
    final unlocked = await controller.unlock();
    if (!mounted) {
      return;
    }
    setState(() {
      _unlocked = unlocked;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_unlocked) {
      return widget.child;
    }

    return Scaffold(
      body: Center(
        child: _checking
            ? const CircularProgressIndicator()
            : FilledButton.icon(
                onPressed: _unlock,
                icon: const Icon(Icons.lock_open_rounded),
                label: const Text('Unlock'),
              ),
      ),
    );
  }
}
