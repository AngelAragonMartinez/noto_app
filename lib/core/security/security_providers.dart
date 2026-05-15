import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_lock_controller.dart';

final appLockControllerProvider = Provider<AppLockController>((ref) {
  return AppLockController();
});
