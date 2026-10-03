import 'package:app/features/rooms/state/rooms_providers.dart';
import 'package:app/features/rooms/ui/room_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConversationPanel extends ConsumerWidget {
  const ConversationPanel({this.onBack, super.key});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = ref.watch(selectedRoomProvider);

    if (room == null) {
      return const Center(child: Text('Selecione uma sala'));
    }

    return Column(
      children: [
        Padding(
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
              RoomAvatar(roomId: room.id, initial: room.initial, radius: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  room.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        const Expanded(child: Center(child: Text('Mensagens em breve'))),
      ],
    );
  }
}
