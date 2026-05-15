import 'dart:convert';

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

  Future<void> write(VaultData data) async {
    final payload = await _codec.encrypt(
      utf8.encode(jsonEncode(data.toJson())),
      await _keyStore.readOrCreateVaultKey(),
    );
    final file = await _paths.vaultFile();
    await file.writeAsString(jsonEncode(payload.toJson()), flush: true);
  }
}
