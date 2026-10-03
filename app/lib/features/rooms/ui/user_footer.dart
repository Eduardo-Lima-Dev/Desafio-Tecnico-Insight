import 'package:app/features/rooms/ui/room_avatar.dart';
import 'package:app/features/session/domain/session.dart';
import 'package:flutter/material.dart';

class UserFooter extends StatelessWidget {
  const UserFooter({required this.session, required this.onLogout, super.key});

  final Session session;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final username = session.username;
    final initial = username.isEmpty
        ? '?'
        : String.fromCharCode(username.runes.first).toUpperCase();

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            RoomAvatar(roomId: session.userId, initial: initial, radius: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(
                    session.userId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: onLogout,
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Sair'),
            ),
          ],
        ),
      ),
    );
  }
}
