import 'package:app/features/rooms/domain/room_summary.dart';
import 'package:app/features/rooms/ui/room_avatar.dart';
import 'package:app/features/rooms/ui/room_time.dart';
import 'package:flutter/material.dart';

class RoomTile extends StatelessWidget {
  const RoomTile({
    required this.room,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final RoomSummary room;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final at = room.lastMessageAt;
    final hasUnread = room.unreadCount > 0;

    return ListTile(
      selected: selected,
      selectedTileColor: theme.colorScheme.primaryContainer.withValues(
        alpha: 0.5,
      ),
      onTap: onTap,
      leading: RoomAvatar(roomId: room.id, initial: room.initial),
      title: Text(
        room.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      subtitle: Text(
        room.lastMessage ?? 'Sem mensagens',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (at != null)
            Text(formatRoomTime(at), style: theme.textTheme.labelSmall),
          if (hasUnread) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                room.unreadCount > 99 ? '99+' : '${room.unreadCount}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
