import 'package:flutter/foundation.dart';

enum MessageKind {
  text,
  encrypted,
  encryptedKeysNeeded,
  encryptedUnavailable,
  other;

  bool get isUndecryptable =>
      this == encrypted ||
      this == encryptedKeysNeeded ||
      this == encryptedUnavailable;
}

enum DeliveryState { sending, sent, failed }

@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.sentAt,
    required this.isOwn,
    this.kind = MessageKind.text,
    this.delivery = DeliveryState.sent,
  });

  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime sentAt;
  final bool isOwn;
  final MessageKind kind;
  final DeliveryState delivery;

  @override
  bool operator ==(Object other) =>
      other is ChatMessage &&
      other.id == id &&
      other.senderId == senderId &&
      other.senderName == senderName &&
      other.text == text &&
      other.sentAt == sentAt &&
      other.isOwn == isOwn &&
      other.kind == kind &&
      other.delivery == delivery;

  @override
  int get hashCode => Object.hash(
    id,
    senderId,
    senderName,
    text,
    sentAt,
    isOwn,
    kind,
    delivery,
  );
}
