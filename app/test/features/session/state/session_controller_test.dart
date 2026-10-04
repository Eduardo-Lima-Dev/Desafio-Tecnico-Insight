import 'package:app/features/session/data/saved_server_repository.dart';
import 'package:app/features/session/data/session_repository.dart';
import 'package:app/features/session/domain/auth_state.dart';
import 'package:app/features/session/domain/session.dart';
import 'package:app/features/session/domain/session_failure.dart';
import 'package:app/features/session/state/saved_server_providers.dart';
import 'package:app/features/session/state/session_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _alice = Session(userId: '@alice:localhost', homeserverUrl: 'http://x');

class FakeSessionRepository implements SessionRepository {
  FakeSessionRepository({this.saved, this.loginFailure, this.logoutError});

  Session? saved;
  SessionFailure? loginFailure;
  Exception? logoutError;
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
    if (logoutError != null) throw logoutError!;
  }
}

class FakeSavedServerRepository implements SavedServerRepository {
  FakeSavedServerRepository({this.value, this.failOnWrite = false});

  String? value;
  bool failOnWrite;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> save(String url) async {
    if (failOnWrite) throw Exception('falha ao gravar');
    value = url;
  }

  @override
  Future<void> clear() async {
    if (failOnWrite) throw Exception('falha ao gravar');
    value = null;
  }
}

class _ThrowingRestoreRepository extends FakeSessionRepository {
  @override
  Future<Session?> restore() async => throw SessionFailure.sessionExpired;
}

ProviderContainer _container(
  FakeSessionRepository repo, {
  FakeSavedServerRepository? saved,
}) {
  final container = ProviderContainer(
    overrides: [
      sessionRepositoryProvider.overrideWithValue(repo),
      savedServerRepositoryProvider.overrideWithValue(
        saved ?? FakeSavedServerRepository(),
      ),
    ],
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
        .submit(
          homeserver: 'x',
          username: 'alice',
          password: 'senha',
          saveServer: false,
        );

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
        .submit(
          homeserver: 'x',
          username: 'alice',
          password: 'errada',
          saveServer: false,
        );

    expect(
      container.read(loginControllerProvider).error,
      SessionFailure.invalidCredentials,
    );
    expect(
      container.read(sessionControllerProvider).requireValue,
      isA<Unauthenticated>(),
    );
  });

  test('login com salvar servidor grava a URL normalizada', () async {
    final saved = FakeSavedServerRepository();
    final container = _container(FakeSessionRepository(), saved: saved);
    await container.read(sessionControllerProvider.future);

    await container
        .read(loginControllerProvider.notifier)
        .submit(
          homeserver: 'localhost:8008',
          username: 'alice',
          password: 'senha',
          saveServer: true,
        );

    expect(saved.value, 'http://localhost:8008');
  });

  test('login sem salvar servidor apaga o servidor salvo', () async {
    final saved = FakeSavedServerRepository(value: 'https://matrix.org');
    final container = _container(FakeSessionRepository(), saved: saved);
    await container.read(sessionControllerProvider.future);

    await container
        .read(loginControllerProvider.notifier)
        .submit(
          homeserver: 'https://matrix.org',
          username: 'alice',
          password: 'senha',
          saveServer: false,
        );

    expect(saved.value, isNull);
  });

  test('login com falha não altera o servidor salvo', () async {
    final saved = FakeSavedServerRepository(value: 'https://matrix.org');
    final container = _container(
      FakeSessionRepository(loginFailure: SessionFailure.invalidCredentials),
      saved: saved,
    );
    await container.read(sessionControllerProvider.future);

    await container
        .read(loginControllerProvider.notifier)
        .submit(
          homeserver: 'https://outro.org',
          username: 'alice',
          password: 'errada',
          saveServer: true,
        );

    expect(saved.value, 'https://matrix.org');
  });

  test('falha ao gravar o servidor não impede o login', () async {
    final container = _container(
      FakeSessionRepository(),
      saved: FakeSavedServerRepository(failOnWrite: true),
    );
    await container.read(sessionControllerProvider.future);

    await container
        .read(loginControllerProvider.notifier)
        .submit(
          homeserver: 'https://matrix.org',
          username: 'alice',
          password: 'senha',
          saveServer: true,
        );

    expect(
      container.read(sessionControllerProvider).requireValue,
      isA<Authenticated>(),
    );
  });

  test('o servidor salvo é carregado ao iniciar', () async {
    final container = _container(
      FakeSessionRepository(),
      saved: FakeSavedServerRepository(value: 'https://matrix.org'),
    );

    expect(
      await container.read(savedServerControllerProvider.future),
      'https://matrix.org',
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

  test('logout volta ao deslogado mesmo se o repositório falhar', () async {
    final repo = FakeSessionRepository(
      saved: _alice,
      logoutError: Exception('falha ao limpar os dados'),
    );
    final container = _container(repo);
    await container.read(sessionControllerProvider.future);

    await expectLater(
      container.read(sessionControllerProvider.notifier).logout(),
      throwsException,
    );

    expect(
      container.read(sessionControllerProvider).requireValue,
      isA<Unauthenticated>(),
    );
  });
}
