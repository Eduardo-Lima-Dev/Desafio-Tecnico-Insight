import 'package:app/features/rooms/domain/room_summary.dart';
import 'package:app/features/rooms/ui/members_label.dart';
import 'package:app/shared/ui/seeded_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> copyRoomId(BuildContext context, RoomSummary room) async {
  await Clipboard.setData(ClipboardData(text: room.id));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('ID da sala copiado.')),
  );
}

Future<void> showRoomDetailsDialog(BuildContext context, RoomSummary room) {
  return showDialog<void>(
    context: context,
    builder: (context) => RoomDetailsDialog(room: room),
  );
}

class RoomDetailsDialog extends StatelessWidget {
  const RoomDetailsDialog({required this.room, super.key});

  final RoomSummary room;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final members = membersLabel(room.memberCount);

    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    scheme.primaryContainer,
                    scheme.primaryContainer.withValues(alpha: 0),
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                child: Column(
                  children: [
                    SeededAvatar(
                      seed: room.id,
                      initial: room.initial,
                      radius: 40,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      room.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  if (members != null)
                    _InfoRow(
                      icon: Icons.group_outlined,
                      label: 'Participantes',
                      value: members,
                    ),
                  _InfoRow(
                    icon: Icons.tag_rounded,
                    label: 'ID da sala',
                    value: room.id,
                    trailing: IconButton(
                      tooltip: 'Copiar ID',
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      onPressed: () => copyRoomId(context, room),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(96, 44),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Fechar'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(icon, size: 20, color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                SelectableText(value, style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
