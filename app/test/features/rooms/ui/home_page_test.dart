import 'dart:async';

import 'package:app/features/chat/data/chat_repository.dart';
import 'package:app/features/chat/domain/chat_message.dart';
import 'package:app/features/chat/state/chat_providers.dart';
import 'package:app/features/conversations/data/conversations_repository.dart';
import 'package:app/features/conversations/domain/conversation_failure.dart';
import 'package:app/features/conversations/domain/room_invite.dart';
import 'package:app/features/conversations/state/conversations_providers.dart';
import 'package:app/features/rooms/data/rooms_repository.dart';
import 'package:app/features/rooms/domain/room_summary.dart';
import 'package:app/features/rooms/domain/sync_status.dart';
import 'package:app/features/rooms/state/rooms_providers.dart';
import 'package:app/features/rooms/ui/connection_banner.dart';
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
  int starts = 0;

  @override
  Future<void> start() async {
    starts++;
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

class _FakeChatRepository implements ChatRepository {
  _FakeChatRepository({this.messages = const {}, this.openError});

  final Map<String, List<ChatMessage>> messages;
  final SessionFailure? openError;
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
  Future<void> send(String roomId, String text) async {}

  @override
  Future<void> retry(String roomId, String messageId) async {}

  @override
  Future<bool> loadOlder(String roomId) async => true;

  @override
  Stream<List<ChatMessage>> watchMessages(String roomId) async* {
    yield messages[roomId] ?? const [];
  }
}

class _FakeConversationsRepository implements ConversationsRepository {
  _FakeConversationsRepository({this.invites = const [], this.failure});

  final List<RoomInvite> invites;
  final ConversationFailure? failure;
  final List<String> created = [];
  final List<String> accepted = [];
  final List<String> declined = [];

  @override
  Future<String> create(String userId) async {
    if (failure != null) throw failure!;
    created.add(userId);
    return '!b';
  }

  @override
  Stream<List<RoomInvite>> watchInvites() async* {
    yield invites;
  }

  @override
  Future<void> accept(String roomId) async => accepted.add(roomId);

  @override
  Future<void> decline(String roomId) async => declined.add(roomId);
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
  _FakeChatRepository? chat,
  _FakeConversationsRepository? conversations,
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
        chatRepositoryProvider.overrideWithValue(chat ?? _FakeChatRepository()),
        conversationsRepositoryProvider.overrideWithValue(
          conversations ?? _FakeConversationsRepository(),
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
    expect(find.text('Nenhuma mensagem ainda.'), findsOneWidget);
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
      find.descendant(of: footer, matching: find.byTooltip('Sair')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: footer, matching: find.text('Sair')),
      findsNothing,
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
    expect(find.byTooltip('Sair'), findsOneWidget);
  });

  testWidgets('tocar em Sair pede confirmação antes de deslogar', (
    tester,
  ) async {
    final session = _FakeSessionRepository();
    await _pump(tester, size: wide, session: session);

    await tester.tap(find.byTooltip('Sair'));
    await tester.pumpAndSettle();

    expect(find.text('Sair da conta?'), findsOneWidget);
    expect(session.logoutCalls, 0);

    await tester.tap(find.widgetWithText(FilledButton, 'Sair'));
    await tester.pumpAndSettle();

    expect(session.logoutCalls, 1);
  });

  testWidgets('cancelar a confirmação não desloga', (tester) async {
    final session = _FakeSessionRepository();
    await _pump(tester, size: wide, session: session);

    await tester.tap(find.byTooltip('Sair'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('Sair da conta?'), findsNothing);
    expect(session.logoutCalls, 0);
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

    expect(find.text('Nenhuma mensagem ainda.'), findsOneWidget);
    expect(find.text('Equipe Insight'), findsNothing);
    expect(find.byType(UserFooter), findsNothing);
    expect(find.byTooltip('Voltar'), findsOneWidget);

    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();

    expect(find.text('Equipe Insight'), findsOneWidget);
    expect(find.text('Nenhuma mensagem ainda.'), findsNothing);
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

  testWidgets('abrir uma sala mostra as mensagens com remetente e horário', (
    tester,
  ) async {
    final chat = _FakeChatRepository(
      messages: {
        '!a': [
          ChatMessage(
            id: '1',
            senderId: '@bob:localhost',
            senderName: 'Bob',
            text: 'Oi, Alice!',
            sentAt: DateTime(2020, 1, 2, 9, 5),
            isOwn: false,
          ),
          ChatMessage(
            id: '2',
            senderId: '@alice:localhost',
            senderName: 'Alice',
            text: 'Oi, Bob! Tudo bem?',
            sentAt: DateTime(2020, 1, 2, 9, 6),
            isOwn: true,
          ),
        ],
      },
    );
    await _pump(tester, size: wide, chat: chat);

    await tester.tap(find.text('Alice e Bob'));
    await tester.pumpAndSettle();

    expect(chat.opened, ['!a']);
    expect(find.text('Oi, Alice!'), findsOneWidget);
    expect(find.text('Oi, Bob! Tudo bem?'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('Alice'), findsNothing);
    expect(find.text('02/01'), findsNWidgets(3));
    expect(find.text('Nenhuma mensagem ainda.'), findsNothing);
  });

  testWidgets(
    'as mensagens próprias ficam à direita e as dos outros à esquerda',
    (
      tester,
    ) async {
      final chat = _FakeChatRepository(
        messages: {
          '!a': [
            ChatMessage(
              id: '1',
              senderId: '@bob:localhost',
              senderName: 'Bob',
              text: 'Mensagem do Bob',
              sentAt: DateTime(2020, 1, 2),
              isOwn: false,
            ),
            ChatMessage(
              id: '2',
              senderId: '@alice:localhost',
              senderName: 'Alice',
              text: 'Mensagem da Alice',
              sentAt: DateTime(2020, 1, 2),
              isOwn: true,
            ),
          ],
        },
      );
      await _pump(tester, size: wide, chat: chat);

      await tester.tap(find.text('Alice e Bob'));
      await tester.pumpAndSettle();

      final other = tester.getCenter(find.text('Mensagem do Bob')).dx;
      final own = tester.getCenter(find.text('Mensagem da Alice')).dx;
      expect(own, greaterThan(other));
    },
  );

  testWidgets('a conversa mais recente fica na parte de baixo', (tester) async {
    final chat = _FakeChatRepository(
      messages: {
        '!a': [
          for (var i = 1; i <= 3; i++)
            ChatMessage(
              id: '$i',
              senderId: '@bob:localhost',
              senderName: 'Bob',
              text: 'Mensagem $i',
              sentAt: DateTime(2020, 1, 2),
              isOwn: false,
            ),
        ],
      },
    );
    await _pump(tester, size: wide, chat: chat);

    await tester.tap(find.text('Alice e Bob'));
    await tester.pumpAndSettle();

    final first = tester.getTopLeft(find.text('Mensagem 1')).dy;
    final last = tester.getTopLeft(find.text('Mensagem 3')).dy;
    expect(last, greaterThan(first));
  });

  testWidgets('mensagem criptografada mostra um aviso no lugar do texto', (
    tester,
  ) async {
    final chat = _FakeChatRepository(
      messages: {
        '!a': [
          ChatMessage(
            id: '1',
            senderId: '@bob:localhost',
            senderName: 'Bob',
            text: '',
            sentAt: DateTime(2020, 1, 2),
            isOwn: false,
            kind: MessageKind.encrypted,
          ),
        ],
      },
    );
    await _pump(tester, size: wide, chat: chat);

    await tester.tap(find.text('Alice e Bob'));
    await tester.pumpAndSettle();

    expect(find.text('Mensagem criptografada'), findsOneWidget);
  });

  testWidgets('falha ao abrir a conversa mostra erro com nova tentativa', (
    tester,
  ) async {
    await _pump(
      tester,
      size: wide,
      chat: _FakeChatRepository(openError: SessionFailure.unknown),
    );

    await tester.tap(find.text('Alice e Bob'));
    await tester.pumpAndSettle();

    expect(find.text('Algo deu errado. Tente novamente.'), findsOneWidget);
    expect(find.text('Tentar de novo'), findsOneWidget);
  });

  testWidgets('trocar de sala abre a nova conversa e fecha a anterior', (
    tester,
  ) async {
    final chat = _FakeChatRepository();
    await _pump(tester, size: wide, chat: chat);

    await tester.tap(find.text('Alice e Bob'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Equipe Insight'));
    await tester.pumpAndSettle();

    expect(chat.opened, ['!a', '!b']);
    expect(chat.closed, contains('!a'));
  });

  testWidgets('a conversa aberta mostra o campo de envio', (tester) async {
    await _pump(tester, size: wide);

    expect(find.text('Digite uma mensagem...'), findsNothing);

    await tester.tap(find.text('Alice e Bob'));
    await tester.pumpAndSettle();

    expect(find.text('Digite uma mensagem...'), findsOneWidget);
    expect(find.byTooltip('Enviar'), findsOneWidget);
  });

  testWidgets('a lista tem o botão de nova conversa', (tester) async {
    await _pump(tester, size: wide);

    expect(find.text('Conversas'), findsOneWidget);
    expect(find.byTooltip('Nova conversa'), findsOneWidget);
  });

  testWidgets('criar uma conversa abre a sala criada', (tester) async {
    final conversations = _FakeConversationsRepository();
    await _pump(tester, size: wide, conversations: conversations);

    await tester.tap(find.byTooltip('Nova conversa'));
    await tester.pumpAndSettle();
    expect(find.text('Nova conversa'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'bob');
    await tester.tap(find.text('Criar'));
    await tester.pumpAndSettle();

    expect(conversations.created, ['@bob:localhost']);
    expect(find.text('Nova conversa'), findsNothing);
    expect(find.text('Selecione uma sala'), findsNothing);
    expect(find.text('Equipe Insight'), findsNWidgets(2));
  });

  testWidgets('usuário inválido mostra o erro e mantém o diálogo', (
    tester,
  ) async {
    final conversations = _FakeConversationsRepository();
    await _pump(tester, size: wide, conversations: conversations);

    await tester.tap(find.byTooltip('Nova conversa'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'bo b');
    await tester.tap(find.text('Criar'));
    await tester.pumpAndSettle();

    expect(
      find.text('Informe um usuário válido, por exemplo @bob:localhost.'),
      findsOneWidget,
    );
    expect(find.text('Nova conversa'), findsOneWidget);
    expect(conversations.created, isEmpty);
  });

  testWidgets('usuário inexistente mostra a mensagem do servidor', (
    tester,
  ) async {
    final conversations = _FakeConversationsRepository(
      failure: ConversationFailure.userNotFound,
    );
    await _pump(tester, size: wide, conversations: conversations);

    await tester.tap(find.byTooltip('Nova conversa'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '@fantasma:localhost');
    await tester.tap(find.text('Criar'));
    await tester.pumpAndSettle();

    expect(find.text('Usuário não encontrado.'), findsOneWidget);
    expect(find.text('Nova conversa'), findsOneWidget);
  });

  testWidgets('cancelar fecha o diálogo sem criar nada', (tester) async {
    final conversations = _FakeConversationsRepository();
    await _pump(tester, size: wide, conversations: conversations);

    await tester.tap(find.byTooltip('Nova conversa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('Nova conversa'), findsNothing);
    expect(conversations.created, isEmpty);
  });

  testWidgets('sem convites a seção de convites não aparece', (tester) async {
    await _pump(tester, size: wide);

    expect(find.text('Convites'), findsNothing);
  });

  testWidgets('convites aparecem acima das conversas', (tester) async {
    const invite = RoomInvite(
      roomId: '!i',
      name: 'Bob',
      inviterId: '@bob:localhost',
      inviterName: 'Bob',
    );
    await _pump(
      tester,
      size: wide,
      conversations: _FakeConversationsRepository(invites: const [invite]),
    );

    expect(find.text('Convites'), findsOneWidget);
    expect(find.text('Convite de Bob'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Convite de Bob')).dy,
      lessThan(tester.getTopLeft(find.text('Alice e Bob')).dy),
    );
  });

  testWidgets('aceitar e recusar um convite chamam o repositório', (
    tester,
  ) async {
    const invites = [
      RoomInvite(
        roomId: '!i1',
        name: 'Bob',
        inviterId: '@bob:localhost',
        inviterName: 'Bob',
      ),
      RoomInvite(
        roomId: '!i2',
        name: 'Carol',
        inviterId: '@carol:localhost',
        inviterName: 'Carol',
      ),
    ];
    final conversations = _FakeConversationsRepository(invites: invites);
    await _pump(tester, size: wide, conversations: conversations);

    await tester.tap(find.byTooltip('Aceitar').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Recusar').last);
    await tester.pumpAndSettle();

    expect(conversations.accepted, ['!i1']);
    expect(conversations.declined, ['!i2']);
  });

  testWidgets('só convites, sem conversas, não mostra o estado vazio', (
    tester,
  ) async {
    const invite = RoomInvite(
      roomId: '!i',
      name: 'Bob',
      inviterId: '@bob:localhost',
      inviterName: 'Bob',
    );
    await _pump(
      tester,
      size: wide,
      rooms: _FakeRoomsRepository(rooms: const []),
      conversations: _FakeConversationsRepository(invites: const [invite]),
    );

    expect(find.text('Convite de Bob'), findsOneWidget);
    expect(
      find.text('Você ainda não participa de nenhuma sala.'),
      findsNothing,
    );
  });

  testWidgets('sem conexão o aviso aparece também com a conversa aberta', (
    tester,
  ) async {
    await _pump(
      tester,
      size: narrow,
      rooms: _FakeRoomsRepository(status: SyncStatus.offline),
    );
    expect(find.text('Sem conexão. Tentando reconectar...'), findsOneWidget);

    await tester.tap(find.text('Alice e Bob'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Voltar'), findsOneWidget);
    expect(find.text('Equipe Insight'), findsNothing);
    expect(find.text('Sem conexão. Tentando reconectar...'), findsOneWidget);
  });

  testWidgets('em janela larga o aviso ocupa o topo de toda a tela', (
    tester,
  ) async {
    await _pump(
      tester,
      size: wide,
      rooms: _FakeRoomsRepository(status: SyncStatus.offline),
    );

    final banner = find.byType(ConnectionBanner);
    expect(tester.getTopLeft(banner).dy, 0);
    expect(tester.getSize(banner).width, wide.width);
    expect(
      tester.getTopLeft(find.text('Alice e Bob')).dy,
      greaterThan(tester.getBottomLeft(banner).dy - 1),
    );
  });

  testWidgets('conectado não mostra nenhum aviso de conexão', (tester) async {
    await _pump(tester, size: wide);

    expect(find.text('Sem conexão. Tentando reconectar...'), findsNothing);
    expect(find.text('Não foi possível sincronizar.'), findsNothing);
  });

  testWidgets('falha na sincronização mostra o aviso com nova tentativa', (
    tester,
  ) async {
    await _pump(
      tester,
      size: wide,
      rooms: _FakeRoomsRepository(status: SyncStatus.failed),
    );

    expect(find.text('Não foi possível sincronizar.'), findsOneWidget);
    expect(find.text('Tentar de novo'), findsOneWidget);
    expect(find.text('Alice e Bob'), findsOneWidget);
  });

  testWidgets('Tentar de novo reinicia a sincronização', (tester) async {
    final rooms = _FakeRoomsRepository(status: SyncStatus.failed);
    await _pump(tester, size: wide, rooms: rooms);
    expect(rooms.starts, 1);

    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();

    expect(rooms.starts, 2);
  });

  testWidgets('a falha de sincronização aparece também em janela estreita', (
    tester,
  ) async {
    await _pump(
      tester,
      size: narrow,
      rooms: _FakeRoomsRepository(status: SyncStatus.failed),
    );

    await tester.tap(find.text('Alice e Bob'));
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível sincronizar.'), findsOneWidget);
  });
}
