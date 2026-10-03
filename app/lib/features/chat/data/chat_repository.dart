import 'package:app/features/chat/domain/chat_message.dart';

abstract interface class ChatRepository {
  Future<void> open(String roomId);

  Future<void> close(String roomId);

  Stream<List<ChatMessage>> watchMessages(String roomId);

  Future<void> send(String roomId, String text);

  Future<void> retry(String roomId, String messageId);

  Future<bool> loadOlder(String roomId);
}
