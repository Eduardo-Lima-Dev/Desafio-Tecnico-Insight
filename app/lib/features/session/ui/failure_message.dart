import 'package:app/features/session/domain/session_failure.dart';

extension SessionFailureMessage on SessionFailure {
  String get message => switch (this) {
    SessionFailure.invalidHomeserver => 'Endereço do servidor inválido.',
    SessionFailure.insecureHomeserver =>
      'Use https:// para conectar ao servidor.',
    SessionFailure.invalidCredentials => 'Usuário ou senha incorretos.',
    SessionFailure.network =>
      'Não foi possível conectar ao servidor. Verifique o endereço e sua '
          'conexão.',
    SessionFailure.rateLimited =>
      'Muitas tentativas. Aguarde um instante e tente de novo.',
    SessionFailure.sessionExpired => 'Sua sessão expirou. Entre novamente.',
    SessionFailure.storage =>
      'Não foi possível acessar os dados locais do aplicativo.',
    SessionFailure.unknown => 'Algo deu errado. Tente novamente.',
  };
}
