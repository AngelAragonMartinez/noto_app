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

  test('rejects decryption with the wrong key', () async {
    final codec = EncryptedCodec();
    final key = List<int>.filled(32, 1);
    final wrongKey = List<int>.filled(32, 2);
    final payload = await codec.encrypt(utf8.encode('private note'), key);

    expect(
      codec.decrypt(payload, wrongKey),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
  });

  test('rejects payloads with an unsupported algorithm', () async {
    final codec = EncryptedCodec();
    final key = List<int>.filled(32, 3);
    final payload = await codec.encrypt(utf8.encode('private note'), key);
    final foreign = EncryptedPayload(
      version: payload.version,
      algorithm: 'ChaCha20-Poly1305',
      nonce: payload.nonce,
      cipherText: payload.cipherText,
      mac: payload.mac,
    );

    expect(codec.decrypt(foreign, key), throwsStateError);
  });

  test('uses a fresh 12-byte nonce for every encryption', () async {
    final codec = EncryptedCodec();
    final key = List<int>.filled(32, 4);
    final clearText = utf8.encode('private note');

    final first = await codec.encrypt(clearText, key);
    final second = await codec.encrypt(clearText, key);

    expect(first.nonce, hasLength(12));
    expect(second.nonce, hasLength(12));
    expect(first.nonce, isNot(second.nonce));
    expect(first.cipherText, isNot(second.cipherText));
  });

  test('round-trips arbitrary binary data', () async {
    final codec = EncryptedCodec();
    final key = List<int>.filled(32, 5);
    final clearText = List<int>.generate(512, (i) => i % 256);

    final payload = await codec.encrypt(clearText, key);
    final decrypted = await codec.decrypt(payload, key);

    expect(decrypted, clearText);
  });
}
