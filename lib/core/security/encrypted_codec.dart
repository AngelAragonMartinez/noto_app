import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class EncryptedPayload {
  const EncryptedPayload({
    required this.version,
    required this.algorithm,
    required this.nonce,
    required this.cipherText,
    required this.mac,
  });

  final int version;
  final String algorithm;
  final List<int> nonce;
  final List<int> cipherText;
  final List<int> mac;

  Map<String, Object?> toJson() => {
        'version': version,
        'algorithm': algorithm,
        'nonce': base64Url.encode(nonce),
        'cipherText': base64Url.encode(cipherText),
        'mac': base64Url.encode(mac),
      };

  factory EncryptedPayload.fromJson(Map<String, Object?> json) {
    return EncryptedPayload(
      version: json['version'] as int,
      algorithm: json['algorithm'] as String,
      nonce: base64Url.decode(json['nonce'] as String),
      cipherText: base64Url.decode(json['cipherText'] as String),
      mac: base64Url.decode(json['mac'] as String),
    );
  }
}

class EncryptedCodec {
  EncryptedCodec({AesGcm? algorithm})
      : _algorithm = algorithm ?? AesGcm.with256bits();

  static const algorithmName = 'AES-256-GCM';

  /// Envelope format this build understands. Bump only alongside a reader that
  /// can still open every older version.
  static const supportedVersion = 1;

  final AesGcm _algorithm;

  Future<EncryptedPayload> encrypt(List<int> clearText, List<int> key) async {
    final nonce = _randomBytes(12);
    final box = await _algorithm.encrypt(
      clearText,
      secretKey: SecretKey(key),
      nonce: nonce,
    );
    return EncryptedPayload(
      version: 1,
      algorithm: algorithmName,
      nonce: nonce,
      cipherText: box.cipherText,
      mac: box.mac.bytes,
    );
  }

  Future<Uint8List> decrypt(EncryptedPayload payload, List<int> key) async {
    if (payload.algorithm != algorithmName) {
      throw StateError('Unsupported vault algorithm: ${payload.algorithm}');
    }
    // Without this, a payload from a future format would fail as an opaque
    // authentication error rather than saying what actually went wrong.
    if (payload.version != supportedVersion) {
      throw StateError('Unsupported vault payload version: ${payload.version}');
    }
    final clearText = await _algorithm.decrypt(
      SecretBox(
        payload.cipherText,
        nonce: payload.nonce,
        mac: Mac(payload.mac),
      ),
      secretKey: SecretKey(key),
    );
    return Uint8List.fromList(clearText);
  }

  List<int> _randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }
}
