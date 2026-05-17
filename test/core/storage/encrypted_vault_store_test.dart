import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:notes_app/core/security/encrypted_codec.dart';
import 'package:notes_app/core/security/secure_key_store.dart';
import 'package:notes_app/core/storage/encrypted_vault_store.dart';
import 'package:notes_app/core/storage/vault_data.dart';
import 'package:notes_app/core/storage/vault_paths.dart';
import 'package:notes_app/features/notes/domain/note.dart';
import 'package:path/path.dart' as p;

class _TempVaultPaths extends VaultPaths {
  _TempVaultPaths(this._dir);
  final Directory _dir;
  @override
  Future<Directory> appDirectory() async => _dir;
  @override
  Future<File> vaultFile() async => File(p.join(_dir.path, 'vault.enc'));
}

class _FixedKeyStore extends SecureKeyStore {
  _FixedKeyStore(this._key);
  final List<int> _key;
  @override
  Future<List<int>> readOrCreateVaultKey() async => _key;
}

void main() {
  late Directory tempDir;
  late EncryptedVaultStore store;
  late File vaultFile;
  late File tmpFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('noto_vault_test_');
    final key = List<int>.generate(32, (i) => i);
    store = EncryptedVaultStore(
      paths: _TempVaultPaths(tempDir),
      keyStore: _FixedKeyStore(key),
      codec: EncryptedCodec(),
    );
    vaultFile = File(p.join(tempDir.path, 'vault.enc'));
    tmpFile = File(p.join(tempDir.path, 'vault.enc.tmp'));
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  group('EncryptedVaultStore atomic write', () {
    test('round-trips data', () async {
      final note = Note(
        id: 'n1',
        title: 'hello',
        body: '',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      await store.write(VaultData(notes: [note]));
      final read = await store.read();
      expect(read.notes, hasLength(1));
      expect(read.notes.first.title, 'hello');
    });

    test('does not leave a .tmp file behind on success', () async {
      await store.write(const VaultData());
      expect(vaultFile.existsSync(), isTrue);
      expect(tmpFile.existsSync(), isFalse);
    });

    test('preserves the previous vault when a stale .tmp file exists', () async {
      await store.write(VaultData(notes: [
        Note(
          id: 'good',
          title: 'good data',
          body: '',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      ]));
      // Simulate a previous interrupted write — a leftover partial .tmp.
      await tmpFile.writeAsString('garbage that would not decrypt');
      // Read should still succeed using the committed vault.enc.
      final read = await store.read();
      expect(read.notes.single.title, 'good data');
    });
  });
}
