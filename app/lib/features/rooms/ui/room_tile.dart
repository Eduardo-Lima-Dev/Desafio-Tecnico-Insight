import 'package:app/features/rooms/domain/room_summary.dart';
import 'package:app/features/rooms/ui/room_time.dart';
import 'package:app/shared/ui/seeded_avatar.dart';
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
    final scheme = theme.colorScheme;
    final at = room.lastMessageAt;
    final hasUnread = room.unreadCount > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: selected ? scheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          hoverColor: scheme.onSurface.withValues(alpha: 0.06),
          child: Stack(
            children: [
              if (selected)
                Positioned(
                  left: 0,
                  top: 10,
                  bottom: 10,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(3),
                      ),
                    ),
                    child: const SizedBox(width: 4),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
                child: Row(
                  children: [
                    SeededAvatar(seed: room.id, initial: room.initial),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            room.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: hasUnread
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            room.lastMessage ?? 'Sem mensagens',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: selected
                                  ? scheme.onPrimaryContainer
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (at != null)
                          Text(
                            formatRoomTime(at),
                            style: theme.textTheme.labelSmall,
                          ),
                        if (hasUnread) ...[
                          const SizedBox(height: 4),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              child: Text(
                                room.unreadCount > 99
                                    ? '99+'
                                    : '${room.unreadCount}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.onPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
