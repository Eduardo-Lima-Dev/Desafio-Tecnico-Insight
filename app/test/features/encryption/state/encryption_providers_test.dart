import 'package:app/features/encryption/domain/encryption_failure.dart';
import 'package:app/features/encryption/state/encryption_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_encryption_repository.dart';

ProviderContainer _container(FakeEncryptionRepository repository) {
  final container = ProviderContainer(
    overrides: [encryptionRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('recuperar com a chave certa devolve verdadeiro', () async {
    final repository = FakeEncryptionRepository();
    final container = _container(repository)
      ..listen(recoveryActionsProvider, (_, _) {});

    final ok = await container
        .read(recoveryActionsProvider.notifier)
        .recover('chave');

    expect(ok, isTrue);
    expect(repository.recovered, ['chave']);
    expect(container.read(recoveryActionsProvider).hasError, isFalse);
  });

  test('chave incorreta deixa o erro tipado no estado', () async {
    final container = _container(
      FakeEncryptionRepository(recoverError: EncryptionFailure.invalidKey),
    )..listen(recoveryActionsProvider, (_, _) {});

    final ok = await container
        .read(recoveryActionsProvider.notifier)
        .recover('errada');

    expect(ok, isFalse);
    expect(
      container.read(recoveryActionsProvider).error,
      EncryptionFailure.invalidKey,
    );
  });

  test('ativar o backup devolve a chave de recuperação', () async {
    final repository = FakeEncryptionRepository(generatedKey: 'ABCD 1234');
    final container = _container(repository)
      ..listen(recoveryActionsProvider, (_, _) {});

    final key = await container.read(recoveryActionsProvider.notifier).enable();

    expect(key, 'ABCD 1234');
    expect(repository.enables, 1);
  });

  test('falha ao ativar o backup vira erro e não devolve chave', () async {
    final container = _container(
      FakeEncryptionRepository(enableError: EncryptionFailure.backupExists),
    )..listen(recoveryActionsProvider, (_, _) {});

    final key = await container.read(recoveryActionsProvider.notifier).enable();

    expect(key, isNull);
    expect(
      container.read(recoveryActionsProvider).error,
      EncryptionFailure.backupExists,
    );
  });
}
