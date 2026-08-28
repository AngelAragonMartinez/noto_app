import 'dart:convert';
import 'dart:io';

import '../security/encrypted_codec.dart';
import '../security/secure_key_store.dart';
import 'vault_data.dart';
import 'vault_paths.dart';
import 'vault_store.dart';

class EncryptedVaultStore implements VaultStore {
  EncryptedVaultStore({
    VaultPaths? paths,
    SecureKeyStore? keyStore,
    EncryptedCodec? codec,
  })  : _paths = paths ?? const VaultPaths(),
        _keyStore = keyStore ?? SecureKeyStore(),
        _codec = codec ?? EncryptedCodec();

  final VaultPaths _paths;
  final SecureKeyStore _keyStore;
  final EncryptedCodec _codec;

  @override
  Future<VaultData> read() async {
    final file = await _paths.vaultFile();
    if (!file.existsSync()) {
      return const VaultData();
    }

    final payloadJson = Map<String, Object?>.from(
      jsonDecode(await file.readAsString()) as Map,
    );
    final payload = EncryptedPayload.fromJson(payloadJson);
    final clearText = await _codec.decrypt(
      payload,
      await _keyStore.readOrCreateVaultKey(),
    );
    return VaultData.fromJson(
      Map<String, Object?>.from(jsonDecode(utf8.decode(clearText)) as Map),
    );
  }

  @override
  Future<void> write(VaultData data) async {
    final payload = await _codec.encrypt(
      utf8.encode(jsonEncode(data.toJson())),
      await _keyStore.readOrCreateVaultKey(),
    );
    // Write to a temp sibling and rename so a crash mid-write can't corrupt
    // the vault. With AES-GCM, any partial bytes would make the whole file
    // fail authentication and the user would lose every note.
    final file = await _paths.vaultFile();
    final tmpFile = File('${file.path}.tmp');
    await tmpFile.writeAsString(jsonEncode(payload.toJson()), flush: true);
    await tmpFile.rename(file.path);
  }
}
