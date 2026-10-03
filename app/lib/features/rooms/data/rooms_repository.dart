import 'package:app/features/rooms/domain/room_summary.dart';
import 'package:app/features/rooms/domain/sync_status.dart';

abstract interface class RoomsRepository {
  Future<void> start();

  Future<void> stop();

  Stream<List<RoomSummary>> watchRooms();

  Stream<SyncStatus> watchStatus();
}
