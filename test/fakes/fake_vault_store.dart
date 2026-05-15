import 'package:notes_app/core/storage/vault_data.dart';
import 'package:notes_app/core/storage/vault_store.dart';

class FakeVaultStore implements VaultStore {
  VaultData data = const VaultData();

  @override
  Future<VaultData> read() async => data;

  @override
  Future<void> write(VaultData data) async {
    this.data = data;
  }
}
