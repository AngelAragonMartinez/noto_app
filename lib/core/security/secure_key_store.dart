import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureKeyStore {
  SecureKeyStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _keyName = 'notes_app_vault_key_v1';
  static const _documentKeyName = 'notes_app_document_key_v1';
  static const _androidOptions = AndroidOptions();
  static const _iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock,
  );

  final FlutterSecureStorage _storage;

  Future<List<int>> readOrCreateVaultKey() => _readOrCreateKey(_keyName);

  Future<List<int>> readOrCreateDocumentKey() {
    return _readOrCreateKey(_documentKeyName);
  }

  Future<List<int>> _readOrCreateKey(String keyName) async {
    final encoded = await _storage.read(
      key: keyName,
      aOptions: _androidOptions,
      iOptions: _iosOptions,
    );
    if (encoded != null) {
      return base64Url.decode(encoded);
    }

    final bytes = _randomBytes(32);
    await _storage.write(
      key: keyName,
      value: base64Url.encode(bytes),
      aOptions: _androidOptions,
      iOptions: _iosOptions,
    );
    return bytes;
  }

  Future<void> resetVaultKey() async {
    await _storage.delete(
      key: _keyName,
      aOptions: _androidOptions,
      iOptions: _iosOptions,
    );
    await _storage.delete(
      key: _documentKeyName,
      aOptions: _androidOptions,
      iOptions: _iosOptions,
    );
  }

  List<int> _randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }
}
