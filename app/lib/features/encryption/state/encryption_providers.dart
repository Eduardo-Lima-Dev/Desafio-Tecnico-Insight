import 'package:app/features/encryption/data/encryption_repository.dart';
import 'package:app/features/encryption/data/matrix_encryption_repository.dart';
import 'package:app/features/encryption/domain/encryption_failure.dart';
import 'package:app/features/encryption/domain/recovery_status.dart';
import 'package:app/features/rooms/state/rooms_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'encryption_providers.g.dart';

Duration? _noRetry(int retryCount, Object error) => null;

@Riverpod(keepAlive: true)
EncryptionRepository encryptionRepository(Ref ref) =>
    MatrixEncryptionRepository();

@Riverpod(retry: _noRetry)
Stream<RecoveryStatus> recoveryStatus(Ref ref) async* {
  await ref.watch(syncServiceProvider.future);
  yield* ref.watch(encryptionRepositoryProvider).watchStatus();
}

@riverpod
class RecoveryActions extends _$RecoveryActions {
  @override
  FutureOr<void> build() {}

  Future<bool> recover(String recoveryKey) async {
    final recovered = await _run(() async {
      await ref.read(encryptionRepositoryProvider).recover(recoveryKey);
      return true;
    });
    return recovered ?? false;
  }

  Future<String?> enable() =>
      _run(() => ref.read(encryptionRepositoryProvider).enableRecovery());

  Future<T?> _run<T>(Future<T> Function() action) async {
    state = const AsyncLoading();
    try {
      final result = await action();
      if (ref.mounted) state = const AsyncData(null);
      return result;
    } on Object catch (error) {
      final failure = error is EncryptionFailure
          ? error
          : EncryptionFailure.unknown;
      if (ref.mounted) state = AsyncError(failure, StackTrace.current);
      return null;
    }
  }
}
