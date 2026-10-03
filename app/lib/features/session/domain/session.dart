import 'package:flutter/foundation.dart';

@immutable
class Session {
  const Session({required this.userId, required this.homeserverUrl});

  final String userId;
  final String homeserverUrl;

  @override
  bool operator ==(Object other) =>
      other is Session &&
      other.userId == userId &&
      other.homeserverUrl == homeserverUrl;

  @override
  int get hashCode => Object.hash(userId, homeserverUrl);
}
