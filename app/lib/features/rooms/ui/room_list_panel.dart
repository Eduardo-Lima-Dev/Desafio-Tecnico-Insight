import 'package:app/features/conversations/domain/conversation_failure.dart';
import 'package:app/features/conversations/domain/room_invite.dart';
import 'package:app/features/conversations/state/conversations_providers.dart';
import 'package:app/features/conversations/ui/conversation_failure_message.dart';
import 'package:app/features/conversations/ui/invite_tile.dart';
import 'package:app/features/conversations/ui/new_conversation_dialog.dart';
import 'package:app/features/rooms/domain/room_summary.dart';
import 'package:app/features/rooms/domain/sync_status.dart';
import 'package:app/features/rooms/state/rooms_providers.dart';
import 'package:app/features/rooms/ui/room_tile.dart';
import 'package:app/features/session/domain/session_failure.dart';
import 'package:app/features/session/ui/failure_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RoomListPanel extends ConsumerWidget {
  const RoomListPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rooms = ref.watch(roomsProvider);
    final status = ref.watch(syncStatusProvider).value;
    final selectedId = ref.watch(selectedRoomIdProvider);
    final invites = ref.watch(invitesProvider).value ?? const <RoomInvite>[];

    ref.listen(inviteActionsProvider, (_, next) {
      final error = next.error;
      if (error == null) return;
      final message = error is ConversationFailure
          ? error.message
          : ConversationFailure.unknown.message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    });

    return Column(
      children: [
        _Header(
          onNewConversation: () async {
            final roomId = await showNewConversationDialog(context);
            if (roomId != null) {
              ref.read(selectedRoomIdProvider.notifier).select(roomId);
            }
          },
        ),
        if (status == SyncStatus.offline) const _OfflineBanner(),
        Expanded(
          child: rooms.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _ErrorView(
              message: error is SessionFailure
                  ? error.message
                  : SessionFailure.unknown.message,
              onRetry: () => ref.invalidate(syncServiceProvider),
            ),
            data: (items) => _RoomList(
              rooms: items,
              invites: invites,
              selectedId: selectedId,
              onSelect: (room) =>
                  ref.read(selectedRoomIdProvider.notifier).select(room.id),
              onAccept: (invite) async {
                final accepted = await ref
                    .read(inviteActionsProvider.notifier)
                    .accept(invite.roomId);
                if (accepted) {
                  ref
                      .read(selectedRoomIdProvider.notifier)
                      .select(invite.roomId);
                }
              },
              onDecline: (invite) => ref
                  .read(inviteActionsProvider.notifier)
                  .decline(invite.roomId),
            ),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onNewConversation});

  final VoidCallback onNewConversation;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Conversas',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_square),
            tooltip: 'Nova conversa',
            onPressed: onNewConversation,
          ),
        ],
      ),
    );
  }
}

class _RoomList extends StatelessWidget {
  const _RoomList({
    required this.rooms,
    required this.invites,
    required this.selectedId,
    required this.onSelect,
    required this.onAccept,
    required this.onDecline,
  });

  final List<RoomSummary> rooms;
  final List<RoomInvite> invites;
  final String? selectedId;
  final ValueChanged<RoomSummary> onSelect;
  final ValueChanged<RoomInvite> onAccept;
  final ValueChanged<RoomInvite> onDecline;

  @override
  Widget build(BuildContext context) {
    if (rooms.isEmpty && invites.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Você ainda não participa de nenhuma sala.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final labelCount = invites.isEmpty ? 0 : 1;

    return ListView.separated(
      itemCount: labelCount + invites.length + rooms.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index < labelCount) return const _SectionLabel('Convites');

        final inviteIndex = index - labelCount;
        if (inviteIndex < invites.length) {
          final invite = invites[inviteIndex];
          return InviteTile(
            invite: invite,
            onAccept: () => onAccept(invite),
            onDecline: () => onDecline(invite),
          );
        }

        final room = rooms[inviteIndex - invites.length];
        return RoomTile(
          room: room,
          selected: room.id == selectedId,
          onTap: () => onSelect(room),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        'Sem conexão. Tentando reconectar...',
        style: TextStyle(color: scheme.onErrorContainer),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onRetry,
              child: const Text('Tentar de novo'),
            ),
          ],
        ),
      ),
    );
  }
}
