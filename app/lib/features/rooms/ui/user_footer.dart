import 'package:app/features/encryption/domain/recovery_status.dart';
import 'package:app/features/encryption/state/encryption_providers.dart';
import 'package:app/features/encryption/ui/encryption_dialog.dart';
import 'package:app/features/session/domain/session.dart';
import 'package:app/shared/ui/dialog_buttons.dart';
import 'package:app/shared/ui/seeded_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserFooter extends ConsumerWidget {
  const UserFooter({required this.session, required this.onLogout, super.key});

  final Session session;
  final VoidCallback onLogout;

  Future<void> _confirmLogout(
    BuildContext context,
    RecoveryStatus status,
  ) async {
    final withoutBackup =
        status == RecoveryStatus.disabled ||
        status == RecoveryStatus.incomplete;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair da conta?'),
        content: Text(
          withoutBackup
              ? 'Você precisará entrar de novo para ver suas conversas. '
                    'Sem o backup das chaves, as mensagens criptografadas '
                    'recebidas neste dispositivo não poderão ser lidas '
                    'depois.'
              : 'Você precisará entrar de novo para ver suas conversas.',
        ),
        actions: [
          DialogCancelButton(
            label: 'Cancelar',
            onPressed: () => Navigator.of(context).pop(false),
          ),
          DialogConfirmButton(
            label: 'Sair',
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (confirmed ?? false) onLogout();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final status =
        ref.watch(recoveryStatusProvider).value ?? RecoveryStatus.unknown;
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
              tooltip: 'Backup das mensagens',
              icon: Badge(
                isLabelVisible: status == RecoveryStatus.incomplete,
                smallSize: 8,
                child: const Icon(Icons.key_outlined, size: 20),
              ),
              onPressed: () => showEncryptionDialog(context),
            ),
            IconButton(
              tooltip: 'Sair',
              icon: const Icon(Icons.logout, size: 20),
              onPressed: () => _confirmLogout(context, status),
            ),
          ],
        ),
      ),
    );
  }
}
