import 'dart:io';

import 'package:app/features/session/data/session_repository.dart';
import 'package:app/features/session/data/session_store.dart';
import 'package:app/features/session/domain/homeserver_url.dart';
import 'package:app/features/session/domain/session.dart';
import 'package:app/features/session/domain/session_failure.dart';
import 'package:app/src/rust/api/session.dart' as rust;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class MatrixSessionRepository implements SessionRepository {
  MatrixSessionRepository(this._store);

  final SessionStore _store;

  Future<String> _dataDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'matrix'));
    await dir.create(recursive: true);
    return dir.path;
  }

  @override
  Future<Session?> restore() async {
    final stored = await _store.readSession();
    if (stored == null) return null;

    try {
      final data = rust.SessionData(
        homeserverUrl: stored['homeserverUrl'] as String,
        userId: stored['userId'] as String,
        deviceId: stored['deviceId'] as String,
        accessToken: stored['accessToken'] as String,
        refreshToken: stored['refreshToken'] as String?,
      );
      await rust.restoreSession(
        session: data,
        dataDir: await _dataDir(),
        passphrase: await _store.readOrCreatePassphrase(),
      );
      return Session(userId: data.userId, homeserverUrl: data.homeserverUrl);
    } on Object catch (error) {
      final failure = _toFailure(error);
      if (failure == SessionFailure.sessionExpired) await _wipeLocalData();
      throw failure;
    }
  }

  @override
  Future<Session> login({
    required String homeserver,
    required String username,
    required String password,
  }) async {
    final url = normalizeHomeserverUrl(homeserver);
    try {
      final data = await rust.login(
        homeserverUrl: url,
        username: username.trim(),
        password: password,
        dataDir: await _dataDir(),
        passphrase: await _store.readOrCreatePassphrase(),
      );
      try {
        await _store.writeSession({
          'homeserverUrl': data.homeserverUrl,
          'userId': data.userId,
          'deviceId': data.deviceId,
          'accessToken': data.accessToken,
          'refreshToken': data.refreshToken,
        });
      } on Object {
        await logout();
        throw SessionFailure.storage;
      }
      return Session(userId: data.userId, homeserverUrl: data.homeserverUrl);
    } on Object catch (error) {
      throw _toFailure(error);
    }
  }

  @override
  Future<void> logout() async {
    try {
      await rust.logout();
    } on Object {
      // Mesmo se o servidor não responder, os dados locais são apagados.
    } finally {
      await _wipeLocalData();
    }
  }

  Future<void> _wipeLocalData() async {
    await _store.clear();
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'matrix'));
    if (dir.existsSync()) await dir.delete(recursive: true);
  }

  SessionFailure _toFailure(Object error) {
    if (error is SessionFailure) return error;
    if (error is rust.AuthError) {
      return switch (error) {
        rust.AuthError.invalidHomeserver => SessionFailure.invalidHomeserver,
        rust.AuthError.network => SessionFailure.network,
        rust.AuthError.invalidCredentials => SessionFailure.invalidCredentials,
        rust.AuthError.rateLimited => SessionFailure.rateLimited,
        rust.AuthError.sessionExpired => SessionFailure.sessionExpired,
        rust.AuthError.storage => SessionFailure.storage,
        rust.AuthError.notLoggedIn ||
        rust.AuthError.unknown => SessionFailure.unknown,
      };
    }
    return SessionFailure.unknown;
  }
}
