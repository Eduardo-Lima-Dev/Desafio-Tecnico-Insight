import 'dart:async';

import 'package:app/features/chat/data/chat_repository.dart';
import 'package:app/features/chat/domain/chat_message.dart';
import 'package:app/features/chat/state/chat_providers.dart';
import 'package:app/features/session/domain/session_failure.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _first = ChatMessage(
  id: '1',
  senderId: '@bob:localhost',
  senderName: 'Bob',
  text: 'Oi',
  sentAt: DateTime(2020, 1, 2),
  isOwn: false,
);

class _FakeChatRepository implements ChatRepository {
  _FakeChatRepository({this.openError});

  final SessionFailure? openError;
  final updates = StreamController<List<ChatMessage>>.broadcast();
  final List<String> opened = [];
  final List<String> closed = [];

  @override
  Future<void> open(String roomId) async {
    opened.add(roomId);
    if (openError != null) throw openError!;
  }

  @override
  Future<void> close(String roomId) async => closed.add(roomId);

  @override
  Stream<List<ChatMessage>> watchMessages(String roomId) async* {
    yield [_first];
    yield* updates.stream;
  }
}

ProviderContainer _container(_FakeChatRepository repository) {
  final container = ProviderContainer(
    overrides: [chatRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('abre a conversa uma única vez e emite as mensagens', () async {
    final repository = _FakeChatRepository();
    final container = _container(repository)
      ..listen(chatMessagesProvider('!a'), (_, _) {});

    final messages = await container.read(chatMessagesProvider('!a').future);

    expect(messages, [_first]);
    expect(repository.opened, ['!a']);
  });

  test('novas mensagens chegam à lista', () async {
    final repository = _FakeChatRepository();
    final container = _container(repository)
      ..listen(chatMessagesProvider('!a'), (_, _) {});
    await container.read(chatMessagesProvider('!a').future);
    await _settle();

    final second = ChatMessage(
      id: '2',
      senderId: '@alice:localhost',
      senderName: 'Alice',
      text: 'Olá',
      sentAt: DateTime(2020, 1, 3),
      isOwn: true,
    );
    repository.updates.add([_first, second]);
    await _settle();

    expect(container.read(chatMessagesProvider('!a')).requireValue, [
      _first,
      second,
    ]);
  });

  test('fecha a conversa quando deixa de ser observada', () async {
    final repository = _FakeChatRepository();
    final container = _container(repository);
    final subscription = container.listen(
      chatMessagesProvider('!a'),
      (_, _) {},
    );
    await container.read(chatMessagesProvider('!a').future);

    subscription.close();
    await _settle();

    expect(repository.closed, ['!a']);
  });

  test('cada sala tem a sua própria conversa', () async {
    final repository = _FakeChatRepository();
    final container = _container(repository)
      ..listen(chatMessagesProvider('!a'), (_, _) {})
      ..listen(chatMessagesProvider('!b'), (_, _) {});

    await container.read(chatMessagesProvider('!a').future);
    await container.read(chatMessagesProvider('!b').future);

    expect(repository.opened, ['!a', '!b']);
  });

  test('falha ao abrir leva as mensagens ao estado de erro', () async {
    final repository = _FakeChatRepository(openError: SessionFailure.unknown);
    final container = _container(repository)
      ..listen(chatMessagesProvider('!a'), (_, _) {});
    await _settle();

    expect(container.read(chatMessagesProvider('!a')).hasError, isTrue);
  });
}
