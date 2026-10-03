import 'package:app/features/session/data/session_repository.dart';
import 'package:app/features/session/domain/auth_state.dart';
import 'package:app/features/session/domain/session.dart';
import 'package:app/features/session/domain/session_failure.dart';
import 'package:app/features/session/state/session_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _alice = Session(userId: '@alice:localhost', homeserverUrl: 'http://x');

class FakeSessionRepository implements SessionRepository {
  FakeSessionRepository({this.saved, this.loginFailure});

  Session? saved;
  SessionFailure? loginFailure;
  int logoutCalls = 0;

  @override
  Future<Session?> restore() async => saved;

  @override
  Future<Session> login({
    required String homeserver,
    required String username,
    required String password,
  }) async {
    if (loginFailure != null) throw loginFailure!;
    saved = _alice;
    return _alice;
  }

  @override
  Future<void> logout() async {
    logoutCalls++;
    saved = null;
  }
}

class _ThrowingRestoreRepository extends FakeSessionRepository {
  @override
  Future<Session?> restore() async => throw SessionFailure.sessionExpired;
}

ProviderContainer _container(FakeSessionRepository repo) {
  final container = ProviderContainer(
    overrides: [sessionRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('sem sessão salva, começa deslogado', () async {
    final container = _container(FakeSessionRepository());

    expect(
      await container.read(sessionControllerProvider.future),
      isA<Unauthenticated>(),
    );
  });

  test('com sessão salva, restaura e fica autenticado', () async {
    final container = _container(FakeSessionRepository(saved: _alice));

    final state = await container.read(sessionControllerProvider.future);

    expect(state, isA<Authenticated>());
    expect((state as Authenticated).session, _alice);
  });

  test('sessão inválida na restauração volta ao login', () async {
    final container = _container(_ThrowingRestoreRepository());

    expect(
      await container.read(sessionControllerProvider.future),
      isA<Unauthenticated>(),
    );
  });

  test('login com sucesso autentica', () async {
    final container = _container(FakeSessionRepository());
    await container.read(sessionControllerProvider.future);

    await container
        .read(loginControllerProvider.notifier)
        .submit(homeserver: 'x', username: 'alice', password: 'senha');

    expect(
      container.read(sessionControllerProvider).requireValue,
      isA<Authenticated>(),
    );
  });

  test('credenciais erradas expõem a falha e não autenticam', () async {
    final container = _container(
      FakeSessionRepository(loginFailure: SessionFailure.invalidCredentials),
    );
    await container.read(sessionControllerProvider.future);
    final subscription = container.listen(loginControllerProvider, (_, _) {});
    addTearDown(subscription.close);

    await container
        .read(loginControllerProvider.notifier)
        .submit(homeserver: 'x', username: 'alice', password: 'errada');

    expect(
      container.read(loginControllerProvider).error,
      SessionFailure.invalidCredentials,
    );
    expect(
      container.read(sessionControllerProvider).requireValue,
      isA<Unauthenticated>(),
    );
  });

  test('logout chama o repositório e volta ao deslogado', () async {
    final repo = FakeSessionRepository(saved: _alice);
    final container = _container(repo);
    await container.read(sessionControllerProvider.future);

    await container.read(sessionControllerProvider.notifier).logout();

    expect(repo.logoutCalls, 1);
    expect(
      container.read(sessionControllerProvider).requireValue,
      isA<Unauthenticated>(),
    );
  });
}
