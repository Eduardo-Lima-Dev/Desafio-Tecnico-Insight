import 'package:app/features/encryption/data/encryption_repository.dart';
import 'package:app/features/encryption/domain/encryption_failure.dart';
import 'package:app/features/encryption/domain/recovery_status.dart';
import 'package:app/src/rust/api/encryption.dart' as rust;

class MatrixEncryptionRepository implements EncryptionRepository {
  @override
  Stream<RecoveryStatus> watchStatus() => rust.watchRecoveryStatus().map(
    (status) => switch (status) {
      rust.RecoveryStatus.unknown => RecoveryStatus.unknown,
      rust.RecoveryStatus.enabled => RecoveryStatus.enabled,
      rust.RecoveryStatus.disabled => RecoveryStatus.disabled,
      rust.RecoveryStatus.incomplete => RecoveryStatus.incomplete,
    },
  );

  @override
  Future<void> recover(String recoveryKey) async {
    try {
      await rust.recoverKeys(recoveryKey: recoveryKey);
    } on Object catch (error) {
      throw _toFailure(error);
    }
  }

  @override
  Future<String> enableRecovery() async {
    try {
      return await rust.enableRecovery();
    } on Object catch (error) {
      throw _toFailure(error);
    }
  }

  EncryptionFailure _toFailure(Object error) {
    if (error is rust.EncryptionError) {
      return switch (error) {
        rust.EncryptionError.notLoggedIn => EncryptionFailure.sessionExpired,
        rust.EncryptionError.invalidKey => EncryptionFailure.invalidKey,
        rust.EncryptionError.backupExists => EncryptionFailure.backupExists,
        rust.EncryptionError.network => EncryptionFailure.network,
        rust.EncryptionError.failed => EncryptionFailure.unknown,
      };
    }
    return EncryptionFailure.unknown;
  }
}
