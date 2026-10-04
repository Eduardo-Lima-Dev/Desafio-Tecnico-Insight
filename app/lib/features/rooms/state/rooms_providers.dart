import 'dart:async';

import 'package:app/features/rooms/data/matrix_rooms_repository.dart';
import 'package:app/features/rooms/data/rooms_repository.dart';
import 'package:app/features/rooms/domain/room_summary.dart';
import 'package:app/features/rooms/domain/sync_status.dart';
import 'package:app/features/session/state/session_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'rooms_providers.g.dart';

Duration? _noRetry(int retryCount, Object error) => null;

@Riverpod(keepAlive: true)
RoomsRepository roomsRepository(Ref ref) => MatrixRoomsRepository();

@Riverpod(retry: _noRetry)
Future<void> syncService(Ref ref) async {
  final repository = ref.watch(roomsRepositoryProvider);
  ref.onDispose(() => unawaited(repository.stop()));
  await repository.start();
}

@Riverpod(retry: _noRetry)
Stream<List<RoomSummary>> rooms(Ref ref) async* {
  await ref.watch(syncServiceProvider.future);
  yield* ref.watch(roomsRepositoryProvider).watchRooms();
}

@Riverpod(retry: _noRetry)
Stream<SyncStatus> syncStatus(Ref ref) async* {
  await ref.watch(syncServiceProvider.future);
  await for (final status in ref.watch(roomsRepositoryProvider).watchStatus()) {
    yield status;
    if (status == SyncStatus.sessionExpired) {
      await ref.read(sessionControllerProvider.notifier).expire();
    }
  }
}

@riverpod
class SelectedRoomId extends _$SelectedRoomId {
  @override
  String? build() => null;

  void select(String? roomId) {
    if (state != roomId) state = roomId;
  }
}

@riverpod
RoomSummary? selectedRoom(Ref ref) {
  final id = ref.watch(selectedRoomIdProvider);
  if (id == null) return null;
  final rooms = ref.watch(roomsProvider).value ?? const <RoomSummary>[];
  for (final room in rooms) {
    if (room.id == id) return room;
  }
  return null;
}
