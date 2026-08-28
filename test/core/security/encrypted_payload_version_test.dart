import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:notes_app/core/security/encrypted_codec.dart';

// Kept out of encrypted_codec_test.dart so this does not collide with the
// codec coverage added in a separate branch.
void main() {
  test('rejects an envelope from an unknown format version', () async {
    final codec = EncryptedCodec();
    final key = List<int>.filled(32, 11);
    final payload = await codec.encrypt(utf8.encode('private note'), key);
    final future = EncryptedPayload(
      version: EncryptedCodec.supportedVersion + 1,
      algorithm: payload.algorithm,
      nonce: payload.nonce,
      cipherText: payload.cipherText,
      mac: payload.mac,
    );

    expect(codec.decrypt(future, key), throwsStateError);
  });

  test('accepts the current format version', () async {
    final codec = EncryptedCodec();
    final key = List<int>.filled(32, 12);
    final payload = await codec.encrypt(utf8.encode('private note'), key);

    expect(payload.version, EncryptedCodec.supportedVersion);
    expect(utf8.decode(await codec.decrypt(payload, key)), 'private note');
  });
}
