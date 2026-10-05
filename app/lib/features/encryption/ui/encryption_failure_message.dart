import 'package:app/features/encryption/domain/encryption_failure.dart';

extension EncryptionFailureMessage on EncryptionFailure {
  String get message => switch (this) {
    EncryptionFailure.invalidKey =>
      'Chave de recuperação incorreta. Confira e tente de novo.',
    EncryptionFailure.backupExists =>
      'Já existe um backup nesta conta. Use a chave de recuperação dele.',
    EncryptionFailure.network =>
      'Não foi possível conectar ao servidor. Verifique sua conexão.',
    EncryptionFailure.sessionExpired => 'Sua sessão expirou. Entre novamente.',
    EncryptionFailure.unknown => 'Algo deu errado. Tente novamente.',
  };
}
