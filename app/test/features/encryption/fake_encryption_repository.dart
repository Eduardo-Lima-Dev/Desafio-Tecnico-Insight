import 'package:app/features/encryption/data/encryption_repository.dart';
import 'package:app/features/encryption/domain/encryption_failure.dart';
import 'package:app/features/encryption/domain/recovery_status.dart';

class FakeEncryptionRepository implements EncryptionRepository {
  FakeEncryptionRepository({
    this.status = RecoveryStatus.enabled,
    this.recoverError,
    this.enableError,
    this.generatedKey = 'EsTx 1111 2222 3333',
  });

  final RecoveryStatus status;
  final EncryptionFailure? recoverError;
  final EncryptionFailure? enableError;
  final String generatedKey;
  final List<String> recovered = [];
  int enables = 0;

  @override
  Stream<RecoveryStatus> watchStatus() async* {
    yield status;
  }

  @override
  Future<void> recover(String recoveryKey) async {
    recovered.add(recoveryKey);
    if (recoverError != null) throw recoverError!;
  }

  @override
  Future<String> enableRecovery() async {
    enables++;
    if (enableError != null) throw enableError!;
    return generatedKey;
  }
}
