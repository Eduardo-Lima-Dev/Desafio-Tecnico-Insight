import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _sessionKey = 'matrix_session';
const _passphraseKey = 'matrix_store_passphrase';

class SessionStore {
  SessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<Map<String, dynamic>?> readSession() async {
    final raw = await _storage.read(key: _sessionKey);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } on FormatException {
      return null;
    }
  }

  Future<void> writeSession(Map<String, dynamic> session) =>
      _storage.write(key: _sessionKey, value: jsonEncode(session));

  Future<String> readOrCreatePassphrase() async {
    final existing = await _storage.read(key: _passphraseKey);
    if (existing != null) return existing;

    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final passphrase = base64UrlEncode(bytes);
    await _storage.write(key: _passphraseKey, value: passphrase);
    return passphrase;
  }

  Future<void> clear() async {
    await _storage.delete(key: _sessionKey);
    await _storage.delete(key: _passphraseKey);
  }
}
