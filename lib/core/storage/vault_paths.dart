import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class VaultPaths {
  const VaultPaths();

  Future<Directory> appDirectory() async {
    final base = await getApplicationSupportDirectory();
    final directory = Directory(p.join(base.path, 'notes_app'));
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    return directory;
  }

  Future<File> vaultFile() async {
    final directory = await appDirectory();
    return File(p.join(directory.path, 'vault.enc'));
  }

  Future<Directory> attachmentsDirectory() async {
    final directory = Directory(
      p.join((await appDirectory()).path, 'attachments'),
    );
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    return directory;
  }

  Future<File> attachmentFile(String vaultName) async {
    final directory = await attachmentsDirectory();
    return File(p.join(directory.path, vaultName));
  }

  Future<Directory> exportsDirectory() async {
    final directory = Directory(p.join((await appDirectory()).path, 'exports'));
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    return directory;
  }
}
