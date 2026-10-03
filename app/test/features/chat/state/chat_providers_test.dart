import 'dart:async';

import 'package:app/features/chat/data/chat_repository.dart';
import 'package:app/features/chat/domain/chat_message.dart';
import 'package:app/features/chat/domain/history_state.dart';
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
  _FakeChatRepository({
    this.openError,
    this.sendError,
    this.olderError,
    this.reachedStart = true,
    this.olderGate,
  });

  final SessionFailure? openError;
  final SessionFailure? sendError;
  final SessionFailure? olderError;
  final bool reachedStart;
  final Completer<void>? olderGate;
  int olderCalls = 0;
  final updates = StreamController<List<ChatMessage>>.broadcast();
  final List<String> opened = [];
  final List<String> closed = [];
  final List<(String, String)> sent = [];
  final List<(String, String)> retried = [];

  @override
  Future<void> open(String roomId) async {
    opened.add(roomId);
    if (openError != null) throw openError!;
  }

  @override
  Future<void> close(String roomId) async => closed.add(roomId);

  @override
  Future<void> send(String roomId, String text) async {
    if (sendError != null) throw sendError!;
    sent.add((roomId, text));
  }

  @override
  Future<void> retry(String roomId, String messageId) async {
    if (sendError != null) throw sendError!;
    retried.add((roomId, messageId));
  }

  @override
  Future<bool> loadOlder(String roomId) async {
    olderCalls++;
    await olderGate?.future;
    if (olderError != null) throw olderError!;
    return reachedStart;
  }

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

  test('o envio chama o repositório com a sala e o texto', () async {
    final repository = _FakeChatRepository();
    final container = _container(repository);

    await container.read(messageSenderProvider.notifier).send('!a', 'Olá');

    expect(repository.sent, [('!a', 'Olá')]);
    expect(container.read(messageSenderProvider).hasError, isFalse);
  });

  test('o reenvio chama o repositório com a sala e a mensagem', () async {
    final repository = _FakeChatRepository();
    final container = _container(repository);

    await container.read(messageSenderProvider.notifier).retry('!a', 'm1');

    expect(repository.retried, [('!a', 'm1')]);
  });

  test('falha ao enviar fica no estado de erro', () async {
    final repository = _FakeChatRepository(sendError: SessionFailure.unknown);
    final container = _container(repository)
      ..listen(messageSenderProvider, (_, _) {});

    await container.read(messageSenderProvider.notifier).send('!a', 'Olá');

    expect(
      container.read(messageSenderProvider).error,
      SessionFailure.unknown,
    );
  });

  test('carregar histórico marca o início quando o Rust avisa', () async {
    final repository = _FakeChatRepository();
    final container = _container(repository)
      ..listen(historyLoaderProvider('!a'), (_, _) {});

    await container.read(historyLoaderProvider('!a').notifier).loadOlder();

    expect(
      container.read(historyLoaderProvider('!a')),
      const HistoryState(reachedStart: true),
    );
  });

  test(
    'carregar histórico sem chegar ao início permite novas páginas',
    () async {
      final repository = _FakeChatRepository(reachedStart: false);
      final container = _container(repository)
        ..listen(historyLoaderProvider('!a'), (_, _) {});
      final loader = container.read(historyLoaderProvider('!a').notifier);

      await loader.loadOlder();
      await loader.loadOlder();

      expect(repository.olderCalls, 2);
      expect(container.read(historyLoaderProvider('!a')), const HistoryState());
    },
  );

  test('depois de chegar ao início não carrega mais', () async {
    final repository = _FakeChatRepository();
    final container = _container(repository)
      ..listen(historyLoaderProvider('!a'), (_, _) {});
    final loader = container.read(historyLoaderProvider('!a').notifier);

    await loader.loadOlder();
    await loader.loadOlder();

    expect(repository.olderCalls, 1);
  });

  test('chamadas simultâneas carregam uma página só', () async {
    final gate = Completer<void>();
    final repository = _FakeChatRepository(olderGate: gate);
    final container = _container(repository)
      ..listen(historyLoaderProvider('!a'), (_, _) {});
    final loader = container.read(historyLoaderProvider('!a').notifier);

    final first = loader.loadOlder();
    final second = loader.loadOlder();
    expect(
      container.read(historyLoaderProvider('!a')),
      const HistoryState(loading: true),
    );
    gate.complete();
    await Future.wait([first, second]);

    expect(repository.olderCalls, 1);
  });

  test(
    'falha ao carregar o histórico marca o erro e permite tentar de novo',
    () async {
      final repository = _FakeChatRepository(
        olderError: SessionFailure.network,
      );
      final container = _container(repository)
        ..listen(historyLoaderProvider('!a'), (_, _) {});
      final loader = container.read(historyLoaderProvider('!a').notifier);

      await loader.loadOlder();
      expect(
        container.read(historyLoaderProvider('!a')),
        const HistoryState(failed: true),
      );

      await loader.loadOlder();
      expect(repository.olderCalls, 2);
    },
  );

  test('cada sala tem o seu próprio estado de histórico', () async {
    final repository = _FakeChatRepository();
    final container = _container(repository)
      ..listen(historyLoaderProvider('!a'), (_, _) {})
      ..listen(historyLoaderProvider('!b'), (_, _) {});

    await container.read(historyLoaderProvider('!a').notifier).loadOlder();

    expect(container.read(historyLoaderProvider('!a')).reachedStart, isTrue);
    expect(container.read(historyLoaderProvider('!b')).reachedStart, isFalse);
  });
}
