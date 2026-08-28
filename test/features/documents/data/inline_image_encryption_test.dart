import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:notes_app/core/security/secure_key_store.dart';
import 'package:notes_app/core/storage/vault_paths.dart';
import 'package:notes_app/features/documents/data/document_repository.dart';
import 'package:path/path.dart' as p;

/// Serves a throwaway directory instead of the real app data directory.
class _TempPaths extends VaultPaths {
  _TempPaths(this.root);

  final Directory root;

  @override
  Future<Directory> appDirectory() async => root;
}

/// Avoids touching the OS keyring in tests.
class _FixedKeyStore extends SecureKeyStore {
  @override
  Future<List<int>> readOrCreateDocumentKey() async => List<int>.filled(32, 9);

  @override
  Future<List<int>> readOrCreateVaultKey() async => List<int>.filled(32, 8);
}

void main() {
  late Directory root;
  late DocumentRepository repository;

  setUp(() {
    root = Directory.systemTemp.createTempSync('noto_inline_image_test_');
    repository = DocumentRepository(
      paths: _TempPaths(root),
      keyStore: _FixedKeyStore(),
    );
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  // A PNG signature, so a plaintext file is unmistakably not JSON.
  final pngBytes = Uint8List.fromList(
    [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3, 4, 5],
  );

  test('inline images are encrypted at rest', () async {
    final path = await repository.storeInlineImageBytes(
      pngBytes,
      fileExtension: '.png',
    );

    final onDisk = File(path).readAsBytesSync();
    expect(onDisk, isNot(pngBytes), reason: 'must not be stored plaintext');
    expect(onDisk.first, 0x7B, reason: 'an EncryptedPayload envelope is JSON');
    expect(
      String.fromCharCodes(onDisk.take(120)),
      contains('AES-256-GCM'),
    );
  });

  test('an encrypted inline image round-trips', () async {
    final path = await repository.storeInlineImageBytes(
      pngBytes,
      fileExtension: '.png',
    );

    expect(await repository.readInlineImage(path), pngBytes);
  });

  test('rejects an unsupported extension rather than trusting it', () async {
    final path = await repository.storeInlineImageBytes(
      pngBytes,
      fileExtension: '.exe',
    );

    expect(p.extension(path), '.png');
  });

  test('still reads images written before encryption, and migrates them',
      () async {
    final dir = Directory(p.join(root.path, 'inline_images'))
      ..createSync(recursive: true);
    final legacy = File(p.join(dir.path, 'legacy.png'))
      ..writeAsBytesSync(pngBytes);

    // Readable despite predating the encrypted format.
    expect(await repository.readInlineImage(legacy.path), pngBytes);

    // Migration is best effort and runs off the read path.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(
      legacy.readAsBytesSync().first,
      0x7B,
      reason: 'legacy plaintext should be re-encrypted in place',
    );
    expect(await repository.readInlineImage(legacy.path), pngBytes);
  });
}
