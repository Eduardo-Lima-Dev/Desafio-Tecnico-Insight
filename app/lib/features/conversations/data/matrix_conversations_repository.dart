import 'package:app/features/conversations/data/conversations_repository.dart';
import 'package:app/features/conversations/domain/conversation_failure.dart';
import 'package:app/features/conversations/domain/room_invite.dart';
import 'package:app/src/rust/api/conversations.dart' as rust;

class MatrixConversationsRepository implements ConversationsRepository {
  @override
  Future<String> create(String userId) async {
    try {
      return await rust.createConversation(userId: userId);
    } on Object catch (error) {
      throw _toFailure(error);
    }
  }

  @override
  Stream<List<RoomInvite>> watchInvites() => rust.watchInvites().map(
    (invites) => invites
        .map(
          (invite) => RoomInvite(
            roomId: invite.roomId,
            name: invite.name,
            inviterId: invite.inviterId,
            inviterName: invite.inviterName,
          ),
        )
        .toList(),
  );

  @override
  Future<void> accept(String roomId) async {
    try {
      await rust.acceptInvite(roomId: roomId);
    } on Object catch (error) {
      throw _toFailure(error);
    }
  }

  @override
  Future<void> decline(String roomId) async {
    try {
      await rust.declineInvite(roomId: roomId);
    } on Object catch (error) {
      throw _toFailure(error);
    }
  }

  ConversationFailure _toFailure(Object error) {
    if (error is rust.ConversationError) {
      return switch (error) {
        rust.ConversationError.notLoggedIn =>
          ConversationFailure.sessionExpired,
        rust.ConversationError.invalidUser => ConversationFailure.invalidUser,
        rust.ConversationError.selfConversation =>
          ConversationFailure.selfConversation,
        rust.ConversationError.userNotFound => ConversationFailure.userNotFound,
        rust.ConversationError.roomNotFound ||
        rust.ConversationError.failed => ConversationFailure.unknown,
      };
    }
    return ConversationFailure.unknown;
  }
}
