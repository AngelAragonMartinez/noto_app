import 'vault_data.dart';

abstract interface class VaultStore {
  Future<VaultData> read();

  Future<void> write(VaultData data);
}
