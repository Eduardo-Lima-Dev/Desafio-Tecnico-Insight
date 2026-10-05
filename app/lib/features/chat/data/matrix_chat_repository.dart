import 'package:app/features/chat/data/chat_repository.dart';
import 'package:app/features/chat/domain/chat_message.dart';
import 'package:app/features/session/domain/session_failure.dart';
import 'package:app/src/rust/api/chat.dart' as rust;

class MatrixChatRepository implements ChatRepository {
  @override
  Future<void> open(String roomId) async {
    try {
      await rust.openRoom(roomId: roomId);
    } on Object catch (error) {
      throw _toFailure(error);
    }
  }

  @override
  Future<void> close(String roomId) async {
    try {
      await rust.closeRoom(roomId: roomId);
    } on Object {
      // Fechar a conversa é uma limpeza: se falhar, não há o que fazer.
    }
  }

  @override
  Stream<List<ChatMessage>> watchMessages(String roomId) => rust
      .watchMessages(roomId: roomId)
      .map((messages) => messages.map(_toMessage).toList());

  @override
  Future<void> send(String roomId, String text) async {
    try {
      await rust.sendMessage(roomId: roomId, text: text);
    } on Object catch (error) {
      throw _toFailure(error);
    }
  }

  @override
  Future<void> retry(String roomId, String messageId) async {
    try {
      await rust.retrySend(roomId: roomId, messageId: messageId);
    } on Object catch (error) {
      throw _toFailure(error);
    }
  }

  @override
  Future<bool> loadOlder(String roomId) async {
    try {
      return await rust.loadOlderMessages(roomId: roomId, count: 30);
    } on Object catch (error) {
      throw _toFailure(error);
    }
  }

  ChatMessage _toMessage(rust.ChatMessage message) => ChatMessage(
    id: message.id,
    senderId: message.senderId,
    senderName: message.senderName,
    text: message.text,
    sentAt: DateTime.fromMillisecondsSinceEpoch(message.sentAtMs.toInt()),
    isOwn: message.isOwn,
    kind: switch (message.kind) {
      rust.MessageKind.text => MessageKind.text,
      rust.MessageKind.encrypted => MessageKind.encrypted,
      rust.MessageKind.encryptedKeysNeeded => MessageKind.encryptedKeysNeeded,
      rust.MessageKind.encryptedUnavailable => MessageKind.encryptedUnavailable,
      rust.MessageKind.other => MessageKind.other,
    },
    delivery: switch (message.delivery) {
      rust.DeliveryState.sending => DeliveryState.sending,
      rust.DeliveryState.sent => DeliveryState.sent,
      rust.DeliveryState.failed => DeliveryState.failed,
    },
  );

  SessionFailure _toFailure(Object error) {
    if (error is rust.ChatError) {
      return switch (error) {
        rust.ChatError.notLoggedIn => SessionFailure.sessionExpired,
        rust.ChatError.roomNotFound ||
        rust.ChatError.messageNotFound ||
        rust.ChatError.failed => SessionFailure.unknown,
      };
    }
    return SessionFailure.unknown;
  }
}
