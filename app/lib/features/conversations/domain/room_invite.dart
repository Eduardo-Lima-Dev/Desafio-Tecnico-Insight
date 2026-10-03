import 'package:flutter/foundation.dart';

@immutable
class RoomInvite {
  const RoomInvite({
    required this.roomId,
    required this.name,
    required this.inviterId,
    required this.inviterName,
  });

  final String roomId;
  final String name;
  final String inviterId;
  final String inviterName;

  @override
  bool operator ==(Object other) =>
      other is RoomInvite &&
      other.roomId == roomId &&
      other.name == name &&
      other.inviterId == inviterId &&
      other.inviterName == inviterName;

  @override
  int get hashCode => Object.hash(roomId, name, inviterId, inviterName);
}
