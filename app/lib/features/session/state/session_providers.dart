import 'package:app/features/session/data/matrix_session_repository.dart';
import 'package:app/features/session/data/session_repository.dart';
import 'package:app/features/session/data/session_store.dart';
import 'package:app/features/session/domain/auth_state.dart';
import 'package:app/features/session/domain/homeserver_url.dart';
import 'package:app/features/session/domain/session.dart';
import 'package:app/features/session/domain/session_failure.dart';
import 'package:app/features/session/state/saved_server_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'session_providers.g.dart';

@Riverpod(keepAlive: true)
SessionRepository sessionRepository(Ref ref) =>
    MatrixSessionRepository(SessionStore());

@Riverpod(keepAlive: true)
class SessionController extends _$SessionController {
  @override
  Future<AuthState> build() async {
    try {
      final session = await ref.read(sessionRepositoryProvider).restore();
      return session == null ? const Unauthenticated() : Authenticated(session);
    } on SessionFailure {
      return const Unauthenticated();
    }
  }

  void signIn(Session session) {
    state = AsyncData(Authenticated(session));
  }

  Future<void> logout() async {
    await ref.read(sessionRepositoryProvider).logout();
    state = const AsyncData(Unauthenticated());
  }

  Future<void> expire() async {
    await ref.read(sessionRepositoryProvider).logout();
    ref
        .read(sessionNoticeProvider.notifier)
        .show(SessionFailure.sessionExpired);
    state = const AsyncData(Unauthenticated());
  }
}

@Riverpod(keepAlive: true)
class SessionNotice extends _$SessionNotice {
  @override
  SessionFailure? build() => null;

  void show(SessionFailure notice) {
    if (state != notice) state = notice;
  }

  void clear() {
    state = null;
  }
}

@riverpod
class LoginController extends _$LoginController {
  @override
  FutureOr<void> build() {}

  Future<void> submit({
    required String homeserver,
    required String username,
    required String password,
    required bool saveServer,
  }) async {
    ref.read(sessionNoticeProvider.notifier).clear();
    state = const AsyncLoading();

    final Session session;
    try {
      session = await ref
          .read(sessionRepositoryProvider)
          .login(
            homeserver: homeserver,
            username: username,
            password: password,
          );
    } on SessionFailure catch (failure) {
      if (ref.mounted) state = AsyncError(failure, StackTrace.current);
      return;
    } on Object {
      if (ref.mounted) {
        state = AsyncError(SessionFailure.unknown, StackTrace.current);
      }
      return;
    }

    if (!ref.mounted) return;
    await _updateSavedServer(homeserver: homeserver, save: saveServer);
    if (!ref.mounted) return;
    state = const AsyncData(null);
    ref.read(sessionControllerProvider.notifier).signIn(session);
  }

  Future<void> _updateSavedServer({
    required String homeserver,
    required bool save,
  }) async {
    final saved = ref.read(savedServerControllerProvider.notifier);
    try {
      if (save) {
        await saved.save(normalizeHomeserverUrl(homeserver));
      } else {
        await saved.clear();
      }
    } on Object {
      // Falhar ao lembrar o servidor não deve impedir o login.
    }
  }
}
