import 'dart:async';

import 'package:app/features/rooms/data/rooms_repository.dart';
import 'package:app/features/rooms/domain/room_summary.dart';
import 'package:app/features/rooms/domain/sync_status.dart';
import 'package:app/features/rooms/state/rooms_providers.dart';
import 'package:app/features/rooms/ui/home_page.dart';
import 'package:app/features/rooms/ui/user_footer.dart';
import 'package:app/features/session/data/session_repository.dart';
import 'package:app/features/session/domain/session.dart';
import 'package:app/features/session/domain/session_failure.dart';
import 'package:app/features/session/state/session_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _alice = Session(userId: '@alice:localhost', homeserverUrl: 'http://x');

final _rooms = [
  RoomSummary(
    id: '!a',
    name: 'Alice e Bob',
    lastMessage: 'Recebi! A conversa chegou.',
    lastMessageAt: DateTime(2020, 1, 2, 10, 30),
    unreadCount: 3,
  ),
  const RoomSummary(id: '!b', name: 'Equipe Insight'),
];

class _FakeRoomsRepository implements RoomsRepository {
  _FakeRoomsRepository({
    List<RoomSummary>? rooms,
    this.status = SyncStatus.running,
    this.startError,
  }) : rooms = rooms ?? _rooms;

  final List<RoomSummary> rooms;
  final SyncStatus status;
  final SessionFailure? startError;

  @override
  Future<void> start() async {
    if (startError != null) throw startError!;
  }

  @override
  Future<void> stop() async {}

  @override
  Stream<List<RoomSummary>> watchRooms() async* {
    yield rooms;
    yield* const Stream<List<RoomSummary>>.empty();
  }

  @override
  Stream<SyncStatus> watchStatus() async* {
    yield status;
  }
}

class _FakeSessionRepository implements SessionRepository {
  int logoutCalls = 0;

  @override
  Future<Session?> restore() async => _alice;

  @override
  Future<Session> login({
    required String homeserver,
    required String username,
    required String password,
  }) async => _alice;

  @override
  Future<void> logout() async => logoutCalls++;
}

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  _FakeRoomsRepository? rooms,
  _FakeSessionRepository? session,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        roomsRepositoryProvider.overrideWithValue(
          rooms ?? _FakeRoomsRepository(),
        ),
        sessionRepositoryProvider.overrideWithValue(
          session ?? _FakeSessionRepository(),
        ),
      ],
      child: const MaterialApp(home: HomePage(session: _alice)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  const wide = Size(1200, 800);
  const narrow = Size(500, 800);

  testWidgets('em janela larga mostra salas e pede para selecionar uma', (
    tester,
  ) async {
    await _pump(tester, size: wide);

    expect(find.text('Alice e Bob'), findsOneWidget);
    expect(find.text('Equipe Insight'), findsOneWidget);
    expect(find.text('Selecione uma sala'), findsOneWidget);
  });

  testWidgets('em janela larga a conversa abre ao lado da lista', (
    tester,
  ) async {
    await _pump(tester, size: wide);

    await tester.tap(find.text('Equipe Insight'));
    await tester.pumpAndSettle();

    expect(find.text('Selecione uma sala'), findsNothing);
    expect(find.text('Mensagens em breve'), findsOneWidget);
    expect(find.text('Alice e Bob'), findsOneWidget);
    expect(find.text('Equipe Insight'), findsNWidgets(2));
  });

  testWidgets('o rodapé mostra o usuário e o botão Sair com ícone', (
    tester,
  ) async {
    await _pump(tester, size: wide);

    final footer = find.byType(UserFooter);
    expect(
      find.descendant(of: footer, matching: find.text('alice')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: footer, matching: find.text('@alice:localhost')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: footer, matching: find.byIcon(Icons.logout)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: footer, matching: find.text('Sair')),
      findsOneWidget,
    );
  });

  testWidgets('o rodapé fica na parte de baixo da lista de salas', (
    tester,
  ) async {
    await _pump(tester, size: wide);

    final footer = find.byType(UserFooter);
    expect(tester.getBottomLeft(footer).dy, wide.height);
    expect(tester.getTopLeft(footer).dx, 0);
    expect(tester.getSize(footer).width, 340);
  });

  testWidgets('não há mais botão Sair no topo da tela', (tester) async {
    await _pump(tester, size: wide);

    expect(find.byType(AppBar), findsNothing);
    expect(find.text('Sair'), findsOneWidget);
  });

  testWidgets('tocar em Sair desloga', (tester) async {
    final session = _FakeSessionRepository();
    await _pump(tester, size: wide, session: session);

    await tester.tap(find.text('Sair'));
    await tester.pumpAndSettle();

    expect(session.logoutCalls, 1);
  });

  testWidgets('em janela estreita mostra a lista com o rodapé', (tester) async {
    await _pump(tester, size: narrow);

    expect(find.text('Selecione uma sala'), findsNothing);
    expect(find.byType(UserFooter), findsOneWidget);
    expect(find.byTooltip('Voltar'), findsNothing);
    expect(tester.getBottomLeft(find.byType(UserFooter)).dy, narrow.height);
  });

  testWidgets('em janela estreita a conversa substitui a lista', (
    tester,
  ) async {
    await _pump(tester, size: narrow);

    await tester.tap(find.text('Alice e Bob'));
    await tester.pumpAndSettle();

    expect(find.text('Mensagens em breve'), findsOneWidget);
    expect(find.text('Equipe Insight'), findsNothing);
    expect(find.byType(UserFooter), findsNothing);
    expect(find.byTooltip('Voltar'), findsOneWidget);

    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();

    expect(find.text('Equipe Insight'), findsOneWidget);
    expect(find.text('Mensagens em breve'), findsNothing);
    expect(find.byType(UserFooter), findsOneWidget);
  });

  testWidgets('cada sala mostra inicial, última mensagem e não lidas', (
    tester,
  ) async {
    await _pump(tester, size: wide);

    expect(find.text('Recebi! A conversa chegou.'), findsOneWidget);
    expect(find.text('Sem mensagens'), findsOneWidget);
    expect(find.text('02/01'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('sem salas mostra o estado vazio', (tester) async {
    await _pump(
      tester,
      size: wide,
      rooms: _FakeRoomsRepository(rooms: const []),
    );

    expect(
      find.text('Você ainda não participa de nenhuma sala.'),
      findsOneWidget,
    );
    expect(find.byType(UserFooter), findsOneWidget);
  });

  testWidgets('sem conexão mostra o aviso de reconexão', (tester) async {
    await _pump(
      tester,
      size: wide,
      rooms: _FakeRoomsRepository(status: SyncStatus.offline),
    );

    expect(find.text('Sem conexão. Tentando reconectar...'), findsOneWidget);
    expect(find.text('Alice e Bob'), findsOneWidget);
  });

  testWidgets('falha ao sincronizar mostra erro com nova tentativa', (
    tester,
  ) async {
    await _pump(
      tester,
      size: wide,
      rooms: _FakeRoomsRepository(startError: SessionFailure.unknown),
    );

    expect(find.text('Algo deu errado. Tente novamente.'), findsOneWidget);
    expect(find.text('Tentar de novo'), findsOneWidget);
    expect(find.byType(UserFooter), findsOneWidget);
  });
}
