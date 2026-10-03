import 'package:flutter/foundation.dart';

@immutable
class Session {
  const Session({required this.userId, required this.homeserverUrl});

  final String userId;
  final String homeserverUrl;

  String get serverName {
    final end = userId.indexOf(':');
    return end == -1 ? '' : userId.substring(end + 1);
  }

  String get username {
    final id = userId.startsWith('@') ? userId.substring(1) : userId;
    final end = id.indexOf(':');
    return end == -1 ? id : id.substring(0, end);
  }

  @override
  bool operator ==(Object other) =>
      other is Session &&
      other.userId == userId &&
      other.homeserverUrl == homeserverUrl;

  @override
  int get hashCode => Object.hash(userId, homeserverUrl);
}
