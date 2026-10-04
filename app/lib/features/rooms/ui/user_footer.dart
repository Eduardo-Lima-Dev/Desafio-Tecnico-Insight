import 'package:app/features/session/domain/session.dart';
import 'package:app/shared/ui/seeded_avatar.dart';
import 'package:flutter/material.dart';

class UserFooter extends StatelessWidget {
  const UserFooter({required this.session, required this.onLogout, super.key});

  final Session session;
  final VoidCallback onLogout;

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair da conta?'),
        content: const Text(
          'Você precisará entrar de novo para ver suas conversas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) onLogout();
  }

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
            SeededAvatar(seed: session.userId, initial: initial, radius: 18),
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
            IconButton(
              tooltip: 'Sair',
              icon: const Icon(Icons.logout, size: 20),
              onPressed: () => _confirmLogout(context),
            ),
          ],
        ),
      ),
    );
  }
}
