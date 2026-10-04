import 'package:app/features/rooms/domain/room_summary.dart';
import 'package:app/shared/ui/seeded_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum _RoomMenuAction { copyId, details }

String? membersLabel(int count) => switch (count) {
  <= 0 => null,
  1 => '1 membro',
  _ => '$count membros',
};

class ConversationHeader extends StatelessWidget {
  const ConversationHeader({required this.room, this.onBack, super.key});

  final RoomSummary room;
  final VoidCallback? onBack;

  Future<void> _onAction(BuildContext context, _RoomMenuAction action) async {
    switch (action) {
      case _RoomMenuAction.copyId:
        await Clipboard.setData(ClipboardData(text: room.id));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ID da sala copiado.')),
        );
      case _RoomMenuAction.details:
        await showDialog<void>(
          context: context,
          builder: (context) => _RoomDetailsDialog(room: room),
        );
    }
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

class _RoomDetailsDialog extends StatelessWidget {
  const _RoomDetailsDialog({required this.room});

  final RoomSummary room;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final members = membersLabel(room.memberCount);

    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SelectableText(value),
        ],
      ),
    );

    return AlertDialog(
      title: const Text('Detalhes da sala'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            row('Nome', room.name),
            if (members != null) row('Participantes', members),
            row('ID da sala', room.id),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}
