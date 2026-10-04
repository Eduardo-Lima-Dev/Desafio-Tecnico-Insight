import 'package:app/features/conversations/domain/room_invite.dart';

abstract interface class ConversationsRepository {
  Future<String> create(String userId);

  Stream<List<RoomInvite>> watchInvites();

  Future<void> accept(String roomId);

  Future<void> decline(String roomId);
}
