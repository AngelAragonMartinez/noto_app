import 'dart:io';

import 'encrypted_vault_store.dart';
import 'sqlcipher_vault_store.dart';
import 'vault_data.dart';
import 'vault_store.dart';

class AdaptiveVaultStore implements VaultStore {
  AdaptiveVaultStore({
    SqlCipherVaultStore? sqlCipherStore,
    EncryptedVaultStore? encryptedStore,
  })  : _sqlCipherStore = sqlCipherStore ?? SqlCipherVaultStore(),
        _encryptedStore = encryptedStore ?? EncryptedVaultStore();

  final SqlCipherVaultStore _sqlCipherStore;
  final EncryptedVaultStore _encryptedStore;

  VaultStore get _activeStore {
    if (Platform.isAndroid || Platform.isIOS) {
      return _sqlCipherStore;
    }
    return _encryptedStore;
  }

  @override
  Future<VaultData> read() => _activeStore.read();

  @override
  Future<void> write(VaultData data) => _activeStore.write(data);
}
