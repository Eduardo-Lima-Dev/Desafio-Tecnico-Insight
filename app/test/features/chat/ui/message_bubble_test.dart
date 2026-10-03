import 'package:app/features/chat/domain/chat_message.dart';
import 'package:app/features/chat/ui/message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessage _message({
  bool isOwn = false,
  MessageKind kind = MessageKind.text,
  DeliveryState delivery = DeliveryState.sent,
}) => ChatMessage(
  id: '1',
  senderId: '@bob:localhost',
  senderName: 'Bob',
  text: 'Olá, tudo bem?',
  sentAt: DateTime(2020, 1, 2, 9, 5),
  isOwn: isOwn,
  kind: kind,
  delivery: delivery,
);

Future<void> _pump(
  WidgetTester tester,
  ChatMessage message, {
  VoidCallback? onRetry,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MessageBubble(message: message, onRetry: onRetry),
      ),
    ),
  );
}

void main() {
  testWidgets('mensagem de outro mostra o nome, o texto e o horário', (
    tester,
  ) async {
    await _pump(tester, _message());

    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('Olá, tudo bem?'), findsOneWidget);
    expect(find.text('02/01'), findsOneWidget);
    expect(find.byIcon(Icons.done), findsNothing);
  });

  testWidgets('mensagem própria não mostra o nome e mostra o estado', (
    tester,
  ) async {
    await _pump(tester, _message(isOwn: true));

    expect(find.text('Bob'), findsNothing);
    expect(find.text('Olá, tudo bem?'), findsOneWidget);
    expect(find.byIcon(Icons.done), findsOneWidget);
  });

  testWidgets('mostra o ícone de cada estado de envio', (tester) async {
    await _pump(tester, _message(isOwn: true, delivery: DeliveryState.sending));
    expect(find.byIcon(Icons.schedule), findsOneWidget);

    await _pump(tester, _message(isOwn: true, delivery: DeliveryState.failed));
    expect(find.byIcon(Icons.error_outline), findsOneWidget);

    await _pump(tester, _message(isOwn: true));
    expect(find.byIcon(Icons.done), findsOneWidget);
  });

  testWidgets('mensagem criptografada mostra o aviso', (tester) async {
    await _pump(tester, _message(kind: MessageKind.encrypted));

    expect(find.text('Mensagem criptografada'), findsOneWidget);
    expect(find.text('Olá, tudo bem?'), findsNothing);
  });

  testWidgets('o texto é exibido como texto puro, sem interpretar HTML', (
    tester,
  ) async {
    final message = ChatMessage(
      id: '1',
      senderId: '@bob:localhost',
      senderName: 'Bob',
      text: '<b>negrito</b> https://exemplo.com',
      sentAt: DateTime(2020, 1, 2),
      isOwn: false,
    );
    await _pump(tester, message);

    expect(find.text('<b>negrito</b> https://exemplo.com'), findsOneWidget);
  });

  testWidgets('tocar no ícone de falha pede o reenvio', (tester) async {
    var retries = 0;
    await _pump(
      tester,
      _message(isOwn: true, delivery: DeliveryState.failed),
      onRetry: () => retries++,
    );

    await tester.tap(find.byIcon(Icons.error_outline));

    expect(retries, 1);
  });

  testWidgets('mensagens enviadas ou enviando não oferecem reenvio', (
    tester,
  ) async {
    var retries = 0;
    await _pump(
      tester,
      _message(isOwn: true, delivery: DeliveryState.sending),
      onRetry: () => retries++,
    );
    await tester.tap(find.byIcon(Icons.schedule));
    await _pump(tester, _message(isOwn: true), onRetry: () => retries++);
    await tester.tap(find.byIcon(Icons.done));

    expect(retries, 0);
  });
}
