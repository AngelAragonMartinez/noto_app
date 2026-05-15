import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_app/core/security/encrypted_codec.dart';

void main() {
  test('encrypts and decrypts clear text', () async {
    final codec = EncryptedCodec();
    final key = List<int>.generate(32, (index) => index);
    final clearText = utf8.encode('private note');

    final payload = await codec.encrypt(clearText, key);
    final decrypted = await codec.decrypt(payload, key);

    expect(payload.cipherText, isNot(clearText));
    expect(utf8.decode(decrypted), 'private note');
  });

  test('rejects tampered payloads', () async {
    final codec = EncryptedCodec();
    final key = List<int>.filled(32, 7);
    final payload = await codec.encrypt(utf8.encode('private note'), key);
    final tampered = EncryptedPayload(
      version: payload.version,
      algorithm: payload.algorithm,
      nonce: payload.nonce,
      cipherText: [...payload.cipherText]..first ^= 1,
      mac: payload.mac,
    );

    expect(
      codec.decrypt(tampered, key),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
  });
}
