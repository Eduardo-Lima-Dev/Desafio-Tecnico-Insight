import 'package:app/features/conversations/data/conversations_repository.dart';
import 'package:app/features/conversations/data/matrix_conversations_repository.dart';
import 'package:app/features/conversations/domain/conversation_failure.dart';
import 'package:app/features/conversations/domain/room_invite.dart';
import 'package:app/features/conversations/domain/user_id.dart';
import 'package:app/features/rooms/state/rooms_providers.dart';
import 'package:app/features/session/domain/auth_state.dart';
import 'package:app/features/session/state/session_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'conversations_providers.g.dart';

Duration? _noRetry(int retryCount, Object error) => null;

@Riverpod(keepAlive: true)
ConversationsRepository conversationsRepository(Ref ref) =>
    MatrixConversationsRepository();

@Riverpod(retry: _noRetry)
Stream<List<RoomInvite>> invites(Ref ref) async* {
  await ref.watch(syncServiceProvider.future);
  yield* ref.watch(conversationsRepositoryProvider).watchInvites();
}

@riverpod
class ConversationCreator extends _$ConversationCreator {
  @override
  FutureOr<void> build() {}

  Future<String?> create(String input) async {
    state = const AsyncLoading();
    try {
      final auth = await ref.read(sessionControllerProvider.future);
      final serverName = auth is Authenticated ? auth.session.serverName : '';
      final userId = normalizeUserId(input, serverName: serverName);
      final roomId = await ref
          .read(conversationsRepositoryProvider)
          .create(userId);
      if (ref.mounted) state = const AsyncData(null);
      return roomId;
    } on ConversationFailure catch (failure) {
      if (ref.mounted) state = AsyncError(failure, StackTrace.current);
    } on Object {
      if (ref.mounted) {
        state = AsyncError(ConversationFailure.unknown, StackTrace.current);
      }
    }
    return null;
  }
}

@riverpod
class InviteActions extends _$InviteActions {
  @override
  FutureOr<void> build() {}

  Future<bool> accept(String roomId) =>
      _run(() => ref.read(conversationsRepositoryProvider).accept(roomId));

  Future<bool> decline(String roomId) =>
      _run(() => ref.read(conversationsRepositoryProvider).decline(roomId));

  Future<bool> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    try {
      await action();
      if (ref.mounted) state = const AsyncData(null);
      return true;
    } on Object catch (error) {
      final failure = error is ConversationFailure
          ? error
          : ConversationFailure.unknown;
      if (ref.mounted) state = AsyncError(failure, StackTrace.current);
      return false;
    }
  }
}
