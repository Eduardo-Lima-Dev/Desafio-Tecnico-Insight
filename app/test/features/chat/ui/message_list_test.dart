import 'dart:async';

import 'package:app/features/chat/data/chat_repository.dart';
import 'package:app/features/chat/domain/chat_message.dart';
import 'package:app/features/chat/state/chat_providers.dart';
import 'package:app/features/chat/ui/message_list.dart';
import 'package:app/features/session/domain/session_failure.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeChatRepository implements ChatRepository {
  _FakeChatRepository({
    this.results = const [true],
    this.error,
    this.gate,
  });

  final List<bool> results;
  final SessionFailure? error;
  final Completer<void>? gate;
  int calls = 0;

  @override
  Future<void> open(String roomId) async {}

  @override
  Future<void> close(String roomId) async {}

  @override
  Stream<List<ChatMessage>> watchMessages(String roomId) async* {}

  @override
  Future<void> send(String roomId, String text) async {}

  @override
  Future<void> retry(String roomId, String messageId) async {}

  @override
  Future<bool> loadOlder(String roomId) async {
    final index = calls < results.length ? calls : results.length - 1;
    calls++;
    await gate?.future;
    if (error != null) throw error!;
    return results[index];
  }
}

List<ChatMessage> _messages(int count) => [
  for (var i = 1; i <= count; i++)
    ChatMessage(
      id: '$i',
      senderId: '@bob:localhost',
      senderName: 'Bob',
      text: 'Mensagem $i',
      sentAt: DateTime(2020, 1, 2),
      isOwn: false,
    ),
];

Future<void> _pump(
  WidgetTester tester,
  _FakeChatRepository repository,
  List<ChatMessage> messages,
) async {
  tester.view.physicalSize = const Size(800, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [chatRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        home: Scaffold(
          body: MessageList(roomId: '!a', messages: messages),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('conversa curta carrega o histórico e mostra o início', (
    tester,
  ) async {
    final repository = _FakeChatRepository();
    await _pump(tester, repository, _messages(3));

    expect(repository.calls, 1);
    expect(find.text('Início da conversa'), findsOneWidget);
  });

  testWidgets('continua carregando enquanto não chega ao início', (
    tester,
  ) async {
    final repository = _FakeChatRepository(results: [false, false, true]);
    await _pump(tester, repository, _messages(3));

    expect(repository.calls, 3);
    expect(find.text('Início da conversa'), findsOneWidget);
  });

  testWidgets('lista vazia não carrega histórico', (tester) async {
    final repository = _FakeChatRepository();
    await _pump(tester, repository, const []);

    expect(repository.calls, 0);
    expect(find.text('Nenhuma mensagem ainda.'), findsOneWidget);
    expect(find.byIcon(Icons.forum_outlined), findsOneWidget);
  });

  testWidgets('agrupa mensagens seguidas e separa por dia', (tester) async {
    final today = DateTime.now();
    final messages = [
      ChatMessage(
        id: '1',
        senderId: '@bob:localhost',
        senderName: 'Bob',
        text: 'Mensagem antiga',
        sentAt: today.subtract(const Duration(days: 1)),
        isOwn: false,
      ),
      ChatMessage(
        id: '2',
        senderId: '@bob:localhost',
        senderName: 'Bob',
        text: 'Primeira de hoje',
        sentAt: today,
        isOwn: false,
      ),
      ChatMessage(
        id: '3',
        senderId: '@bob:localhost',
        senderName: 'Bob',
        text: 'Segunda de hoje',
        sentAt: today,
        isOwn: false,
      ),
    ];
    await _pump(tester, _FakeChatRepository(), messages);

    expect(find.text('Hoje'), findsOneWidget);
    expect(find.text('Ontem'), findsOneWidget);
    expect(find.text('Bob'), findsNWidgets(2));
    expect(find.byType(CircleAvatar), findsNWidgets(2));
  });

  testWidgets('conversa longa só carrega ao rolar até o topo', (tester) async {
    final repository = _FakeChatRepository(results: [false, true]);
    await _pump(tester, repository, _messages(60));

    expect(repository.calls, 0);
    expect(find.text('Mensagem 60'), findsOneWidget);
    expect(find.text('Início da conversa'), findsNothing);

    await tester.fling(find.byType(ListView), const Offset(0, 4000), 6000);
    await tester.pumpAndSettle();

    expect(repository.calls, greaterThanOrEqualTo(1));
  });

  testWidgets('mostra o indicador enquanto carrega mais mensagens', (
    tester,
  ) async {
    final gate = Completer<void>();
    final repository = _FakeChatRepository(gate: gate);
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [chatRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          home: Scaffold(
            body: MessageList(roomId: '!a', messages: _messages(3)),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Início da conversa'), findsOneWidget);
  });

  testWidgets('falha ao carregar mostra erro e permite tentar de novo', (
    tester,
  ) async {
    final repository = _FakeChatRepository(error: SessionFailure.network);
    await _pump(tester, repository, _messages(3));

    expect(repository.calls, 1);
    expect(
      find.text('Não foi possível carregar o histórico. Tentar de novo'),
      findsOneWidget,
    );

    await tester.tap(find.textContaining('Tentar de novo'));
    await tester.pumpAndSettle();

    expect(repository.calls, 2);
  });
}
