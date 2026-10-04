import 'package:app/features/conversations/domain/room_invite.dart';
import 'package:app/features/rooms/ui/room_avatar.dart';
import 'package:flutter/material.dart';

class InviteTile extends StatelessWidget {
  const InviteTile({
    required this.invite,
    required this.onAccept,
    required this.onDecline,
    super.key,
  });

  final RoomInvite invite;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = invite.name.trim().isEmpty
        ? '?'
        : String.fromCharCode(invite.name.trim().runes.first).toUpperCase();

    return ListTile(
      leading: RoomAvatar(roomId: invite.roomId, initial: initial),
      title: Text(
        invite.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        'Convite de ${invite.inviterName}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.check_circle_outline),
            color: theme.colorScheme.primary,
            tooltip: 'Aceitar',
            onPressed: onAccept,
          ),
          IconButton(
            icon: const Icon(Icons.cancel_outlined),
            tooltip: 'Recusar',
            onPressed: onDecline,
          ),
        ],
      ),
    );
  }
}
