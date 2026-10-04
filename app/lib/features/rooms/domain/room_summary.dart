import 'package:flutter/foundation.dart';

@immutable
class RoomSummary {
  const RoomSummary({
    required this.id,
    required this.name,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.memberCount = 0,
  });

  final String id;
  final String name;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final int memberCount;

  String get initial {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return String.fromCharCode(trimmed.runes.first).toUpperCase();
  }

  @override
  bool operator ==(Object other) =>
      other is RoomSummary &&
      other.id == id &&
      other.name == name &&
      other.lastMessage == lastMessage &&
      other.lastMessageAt == lastMessageAt &&
      other.unreadCount == unreadCount &&
      other.memberCount == memberCount;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    lastMessage,
    lastMessageAt,
    unreadCount,
    memberCount,
  );
}
