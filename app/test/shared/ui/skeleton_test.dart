import 'package:app/shared/ui/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('o esqueleto da lista de salas anuncia o carregamento', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: RoomListSkeleton())),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.bySemanticsLabel('Carregando conversas'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('o esqueleto das mensagens anuncia o carregamento', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MessageListSkeleton())),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.bySemanticsLabel('Carregando mensagens'), findsOneWidget);
  });
}
