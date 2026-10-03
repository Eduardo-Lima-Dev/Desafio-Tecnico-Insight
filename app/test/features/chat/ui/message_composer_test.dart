import 'package:app/features/chat/data/chat_repository.dart';
import 'package:app/features/chat/domain/chat_message.dart';
import 'package:app/features/chat/state/chat_providers.dart';
import 'package:app/features/chat/ui/message_composer.dart';
import 'package:app/features/session/domain/session_failure.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeChatRepository implements ChatRepository {
  _FakeChatRepository({this.sendError});

  final SessionFailure? sendError;
  final List<(String, String)> sent = [];

  @override
  Future<void> open(String roomId) async {}

  @override
  Future<void> close(String roomId) async {}

  @override
  Stream<List<ChatMessage>> watchMessages(String roomId) async* {}

  @override
  Future<void> send(String roomId, String text) async {
    if (sendError != null) throw sendError!;
    sent.add((roomId, text));
  }

  @override
  Future<void> retry(String roomId, String messageId) async {}
}

Future<void> _pump(
  WidgetTester tester,
  _FakeChatRepository repository, {
  String roomId = '!a',
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [chatRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const Expanded(child: SizedBox.shrink()),
              MessageComposer(key: ValueKey(roomId), roomId: roomId),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

IconButton _sendButton(WidgetTester tester) =>
    tester.widget<IconButton>(find.byType(IconButton));

String _fieldText(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).controller!.text;

void main() {
  testWidgets('o botão de enviar começa desabilitado', (tester) async {
    await _pump(tester, _FakeChatRepository());

    expect(_sendButton(tester).onPressed, isNull);
  });

  testWidgets('texto só com espaços não habilita o envio', (tester) async {
    await _pump(tester, _FakeChatRepository());

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();

    expect(_sendButton(tester).onPressed, isNull);
  });

  testWidgets('o botão envia o texto e limpa o campo', (tester) async {
    final repository = _FakeChatRepository();
    await _pump(tester, repository);

    await tester.enterText(find.byType(TextField), 'Olá, pessoal');
    await tester.pump();
    await tester.tap(find.byTooltip('Enviar'));
    await tester.pumpAndSettle();

    expect(repository.sent, [('!a', 'Olá, pessoal')]);
    expect(_fieldText(tester), isEmpty);
    expect(_sendButton(tester).onPressed, isNull);
  });

  testWidgets('Enter envia a mensagem', (tester) async {
    final repository = _FakeChatRepository();
    await _pump(tester, repository);

    await tester.enterText(find.byType(TextField), 'Enviada pelo Enter');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(repository.sent, [('!a', 'Enviada pelo Enter')]);
    expect(_fieldText(tester), isEmpty);
  });

  testWidgets('Shift+Enter não envia a mensagem', (tester) async {
    final repository = _FakeChatRepository();
    await _pump(tester, repository);

    await tester.enterText(find.byType(TextField), 'Primeira linha');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();

    expect(repository.sent, isEmpty);
    expect(_fieldText(tester), 'Primeira linha');
  });

  testWidgets('Enter com o campo vazio não envia nada', (tester) async {
    final repository = _FakeChatRepository();
    await _pump(tester, repository);

    await tester.tap(find.byType(TextField));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(repository.sent, isEmpty);
  });

  testWidgets('falha ao enviar mostra um aviso', (tester) async {
    final repository = _FakeChatRepository(sendError: SessionFailure.unknown);
    await _pump(tester, repository);

    await tester.enterText(find.byType(TextField), 'Olá');
    await tester.pump();
    await tester.tap(find.byTooltip('Enviar'));
    await tester.pumpAndSettle();

    expect(find.text('Algo deu errado. Tente novamente.'), findsOneWidget);
  });
}
