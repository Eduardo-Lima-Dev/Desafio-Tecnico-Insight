import 'package:app/features/rooms/domain/room_summary.dart';
import 'package:app/features/rooms/ui/members_label.dart';
import 'package:app/features/rooms/ui/room_details_dialog.dart';
import 'package:app/shared/ui/seeded_avatar.dart';
import 'package:flutter/material.dart';

enum _RoomMenuAction { copyId, details }

class ConversationHeader extends StatelessWidget {
  const ConversationHeader({required this.room, this.onBack, super.key});

  final RoomSummary room;
  final VoidCallback? onBack;

  Future<void> _onAction(BuildContext context, _RoomMenuAction action) {
    return switch (action) {
      _RoomMenuAction.copyId => copyRoomId(context, room),
      _RoomMenuAction.details => showRoomDetailsDialog(context, room),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = membersLabel(room.memberCount);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Voltar',
              onPressed: onBack,
            )
          else
            const SizedBox(width: 8),
          SeededAvatar(seed: room.id, initial: room.initial, radius: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  room.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          PopupMenuButton<_RoomMenuAction>(
            tooltip: 'Mais opções',
            icon: const Icon(Icons.more_vert),
            onSelected: (action) => _onAction(context, action),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _RoomMenuAction.details,
                child: Text('Detalhes da sala'),
              ),
              PopupMenuItem(
                value: _RoomMenuAction.copyId,
                child: Text('Copiar ID da sala'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
