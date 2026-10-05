import 'package:app/features/encryption/domain/recovery_status.dart';

abstract interface class EncryptionRepository {
  Stream<RecoveryStatus> watchStatus();

  Future<void> recover(String recoveryKey);

  Future<String> enableRecovery();
}
