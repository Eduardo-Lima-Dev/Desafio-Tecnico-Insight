import 'dart:async';

import 'package:app/features/conversations/data/conversations_repository.dart';
import 'package:app/features/conversations/domain/conversation_failure.dart';
import 'package:app/features/conversations/domain/room_invite.dart';
import 'package:app/features/conversations/state/conversations_providers.dart';
import 'package:app/features/rooms/data/rooms_repository.dart';
import 'package:app/features/rooms/domain/room_summary.dart';
import 'package:app/features/rooms/domain/sync_status.dart';
import 'package:app/features/rooms/state/rooms_providers.dart';
import 'package:app/features/session/data/session_repository.dart';
import 'package:app/features/session/domain/session.dart';
import 'package:app/features/session/state/session_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _alice = Session(userId: '@alice:localhost', homeserverUrl: 'http://x');

const _invite = RoomInvite(
  roomId: '!i',
  name: 'Bob',
  inviterId: '@bob:localhost',
  inviterName: 'Bob',
);

class _FakeConversationsRepository implements ConversationsRepository {
  _FakeConversationsRepository({this.failure});

  final ConversationFailure? failure;
  final List<String> created = [];
  final List<String> accepted = [];
  final List<String> declined = [];
  final updates = StreamController<List<RoomInvite>>.broadcast();

  @override
  Future<String> create(String userId) async {
    if (failure != null) throw failure!;
    created.add(userId);
    return '!new';
  }

  @override
  Stream<List<RoomInvite>> watchInvites() async* {
    yield [_invite];
    yield* updates.stream;
  }

  @override
  Future<void> accept(String roomId) async {
    if (failure != null) throw failure!;
    accepted.add(roomId);
  }

  @override
  Future<void> decline(String roomId) async {
    if (failure != null) throw failure!;
    declined.add(roomId);
  }
}

class _FakeRoomsRepository implements RoomsRepository {
  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Stream<List<RoomSummary>> watchRooms() async* {}

  @override
  Stream<SyncStatus> watchStatus() async* {}
}

class _FakeSessionRepository implements SessionRepository {
  @override
  Future<Session?> restore() async => _alice;

  @override
  Future<Session> login({
    required String homeserver,
    required String username,
    required String password,
  }) async => _alice;

  @override
  Future<void> logout() async {}
}

ProviderContainer _container(_FakeConversationsRepository repository) {
  final container = ProviderContainer(
    overrides: [
      conversationsRepositoryProvider.overrideWithValue(repository),
      roomsRepositoryProvider.overrideWithValue(_FakeRoomsRepository()),
      sessionRepositoryProvider.overrideWithValue(_FakeSessionRepository()),
    ],
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
  test('criar completa o usuário e devolve a sala criada', () async {
    final repository = _FakeConversationsRepository();
    final container = _container(repository)
      ..listen(conversationCreatorProvider, (_, _) {});

    final roomId = await container
        .read(conversationCreatorProvider.notifier)
        .create('bob');

    expect(roomId, '!new');
    expect(repository.created, ['@bob:localhost']);
    expect(container.read(conversationCreatorProvider).hasError, isFalse);
  });

  test('criar com usuário inválido não chama o servidor', () async {
    final repository = _FakeConversationsRepository();
    final container = _container(repository)
      ..listen(conversationCreatorProvider, (_, _) {});

    final roomId = await container
        .read(conversationCreatorProvider.notifier)
        .create('  ');

    expect(roomId, isNull);
    expect(repository.created, isEmpty);
    expect(
      container.read(conversationCreatorProvider).error,
      ConversationFailure.invalidUser,
    );
  });

  test('falha do servidor vira erro de domínio', () async {
    final repository = _FakeConversationsRepository(
      failure: ConversationFailure.userNotFound,
    );
    final container = _container(repository)
      ..listen(conversationCreatorProvider, (_, _) {});

    final roomId = await container
        .read(conversationCreatorProvider.notifier)
        .create('@fantasma:localhost');

    expect(roomId, isNull);
    expect(
      container.read(conversationCreatorProvider).error,
      ConversationFailure.userNotFound,
    );
  });

  test('os convites chegam do repositório', () async {
    final repository = _FakeConversationsRepository();
    final container = _container(repository)
      ..listen(invitesProvider, (_, _) {});

    expect(await container.read(invitesProvider.future), [_invite]);
  });

  test('novos convites atualizam a lista', () async {
    final repository = _FakeConversationsRepository();
    final container = _container(repository)
      ..listen(invitesProvider, (_, _) {});
    await container.read(invitesProvider.future);
    await _settle();

    repository.updates.add(const []);
    await _settle();

    expect(container.read(invitesProvider).requireValue, isEmpty);
  });

  test('aceitar e recusar chamam o repositório', () async {
    final repository = _FakeConversationsRepository();
    final container = _container(repository)
      ..listen(inviteActionsProvider, (_, _) {});
    final actions = container.read(inviteActionsProvider.notifier);

    expect(await actions.accept('!a'), isTrue);
    expect(await actions.decline('!b'), isTrue);

    expect(repository.accepted, ['!a']);
    expect(repository.declined, ['!b']);
  });

  test('falha ao aceitar devolve falso e deixa o erro no estado', () async {
    final repository = _FakeConversationsRepository(
      failure: ConversationFailure.unknown,
    );
    final container = _container(repository)
      ..listen(inviteActionsProvider, (_, _) {});

    final accepted = await container
        .read(inviteActionsProvider.notifier)
        .accept('!a');

    expect(accepted, isFalse);
    expect(
      container.read(inviteActionsProvider).error,
      ConversationFailure.unknown,
    );
  });
}
