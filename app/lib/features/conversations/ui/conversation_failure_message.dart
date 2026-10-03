import 'package:app/features/conversations/domain/conversation_failure.dart';

extension ConversationFailureMessage on ConversationFailure {
  String get message => switch (this) {
    ConversationFailure.invalidUser =>
      'Informe um usuário válido, por exemplo @bob:localhost.',
    ConversationFailure.selfConversation =>
      'Você não pode abrir uma conversa com você mesmo.',
    ConversationFailure.userNotFound => 'Usuário não encontrado.',
    ConversationFailure.sessionExpired =>
      'Sua sessão expirou. Entre novamente.',
    ConversationFailure.unknown => 'Algo deu errado. Tente novamente.',
  };
}
