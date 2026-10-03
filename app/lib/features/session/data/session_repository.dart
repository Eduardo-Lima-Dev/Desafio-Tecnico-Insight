import 'package:app/features/session/domain/session.dart';

abstract interface class SessionRepository {
  Future<Session?> restore();

  Future<Session> login({
    required String homeserver,
    required String username,
    required String password,
  });

  Future<void> logout();
}
