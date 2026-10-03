import 'dart:async';

import 'package:app/features/chat/data/chat_repository.dart';
import 'package:app/features/chat/data/matrix_chat_repository.dart';
import 'package:app/features/chat/domain/chat_message.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'chat_providers.g.dart';

Duration? _noRetry(int retryCount, Object error) => null;

@Riverpod(keepAlive: true)
ChatRepository chatRepository(Ref ref) => MatrixChatRepository();

@Riverpod(retry: _noRetry)
Future<void> openChat(Ref ref, String roomId) async {
  final repository = ref.watch(chatRepositoryProvider);
  ref.onDispose(() => unawaited(repository.close(roomId)));
  await repository.open(roomId);
}

@Riverpod(retry: _noRetry)
Stream<List<ChatMessage>> chatMessages(Ref ref, String roomId) async* {
  await ref.watch(openChatProvider(roomId).future);
  yield* ref.watch(chatRepositoryProvider).watchMessages(roomId);
}

@riverpod
class MessageSender extends _$MessageSender {
  @override
  FutureOr<void> build() {}

  Future<void> send(String roomId, String text) =>
      _run(() => ref.read(chatRepositoryProvider).send(roomId, text));

  Future<void> retry(String roomId, String messageId) =>
      _run(() => ref.read(chatRepositoryProvider).retry(roomId, messageId));

  Future<void> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(action);
    if (ref.mounted) state = result;
  }
}
