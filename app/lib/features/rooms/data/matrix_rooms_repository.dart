import 'package:app/features/rooms/data/rooms_repository.dart';
import 'package:app/features/rooms/domain/room_summary.dart';
import 'package:app/features/rooms/domain/sync_status.dart';
import 'package:app/features/session/domain/session_failure.dart';
import 'package:app/src/rust/api/rooms.dart' as rust;

class MatrixRoomsRepository implements RoomsRepository {
  @override
  Future<void> start() async {
    try {
      await rust.startSync();
    } on Object catch (error) {
      throw _toFailure(error);
    }
  }

  @override
  Future<void> stop() async {
    try {
      await rust.stopSync();
    } on Object {
      // Encerrar a sincronização é uma limpeza: se falhar, não há o que fazer.
    }
  }

  @override
  Stream<List<RoomSummary>> watchRooms() =>
      rust.watchRooms().map((rooms) => rooms.map(_toRoom).toList());

  @override
  Stream<SyncStatus> watchStatus() => rust.watchSyncStatus().map(_toStatus);

  RoomSummary _toRoom(rust.RoomSummary room) {
    final at = room.lastMessageAtMs;
    return RoomSummary(
      id: room.id,
      name: room.name,
      lastMessage: room.lastMessage,
      lastMessageAt: at == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(at.toInt()),
      unreadCount: room.unreadCount.toInt(),
      memberCount: room.memberCount.toInt(),
    );
  }

  SyncStatus _toStatus(rust.SyncStatus status) => switch (status) {
    rust.SyncStatus.running => SyncStatus.running,
    rust.SyncStatus.offline => SyncStatus.offline,
    rust.SyncStatus.sessionExpired => SyncStatus.sessionExpired,
    rust.SyncStatus.failed => SyncStatus.failed,
    rust.SyncStatus.idle || rust.SyncStatus.stopped => SyncStatus.connecting,
  };

  SessionFailure _toFailure(Object error) {
    if (error is rust.SyncError) {
      return switch (error) {
        rust.SyncError.notLoggedIn ||
        rust.SyncError.sessionExpired => SessionFailure.sessionExpired,
        rust.SyncError.failed => SessionFailure.unknown,
      };
    }
    return SessionFailure.unknown;
  }
}
