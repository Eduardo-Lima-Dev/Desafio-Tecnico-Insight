import 'package:app/features/conversations/domain/conversation_failure.dart';
import 'package:app/features/conversations/domain/room_invite.dart';
import 'package:app/features/conversations/state/conversations_providers.dart';
import 'package:app/features/conversations/ui/conversation_failure_message.dart';
import 'package:app/features/conversations/ui/invite_tile.dart';
import 'package:app/features/conversations/ui/new_conversation_dialog.dart';
import 'package:app/features/rooms/domain/room_summary.dart';
import 'package:app/features/rooms/domain/search_text.dart';
import 'package:app/features/rooms/state/rooms_providers.dart';
import 'package:app/features/rooms/ui/room_tile.dart';
import 'package:app/features/session/domain/session_failure.dart';
import 'package:app/features/session/ui/failure_message.dart';
import 'package:app/shared/ui/empty_state.dart';
import 'package:app/shared/ui/error_state.dart';
import 'package:app/shared/ui/skeleton.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RoomListPanel extends ConsumerWidget {
  const RoomListPanel({required this.searchFocusNode, super.key});

  final FocusNode searchFocusNode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rooms = ref.watch(roomsProvider);
    final selectedId = ref.watch(selectedRoomIdProvider);
    final invites = ref.watch(invitesProvider).value ?? const <RoomInvite>[];
    final query = ref.watch(roomSearchQueryProvider);

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
        _SearchField(focusNode: searchFocusNode),
        Expanded(
          child: rooms.when(
            loading: () => const RoomListSkeleton(),
            error: (error, _) => ErrorState(
              message: error is SessionFailure
                  ? error.message
                  : SessionFailure.unknown.message,
              onRetry: () => ref.invalidate(syncServiceProvider),
            ),
            data: (items) => _RoomList(
              rooms: items
                  .where((room) => matchesSearch(room.name, query))
                  .toList(),
              invites: invites
                  .where((invite) => matchesSearch(invite.name, query))
                  .toList(),
              searching: query.trim().isNotEmpty,
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

class _SearchField extends ConsumerStatefulWidget {
  const _SearchField({required this.focusNode});

  final FocusNode focusNode;

  @override
  ConsumerState<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends ConsumerState<_SearchField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    ref.read(roomSearchQueryProvider.notifier).query = '';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shortcut = defaultTargetPlatform == TargetPlatform.macOS
        ? '⌘K'
        : 'Ctrl+K';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Focus(
        onKeyEvent: (_, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            _clear();
            widget.focusNode.unfocus(
              disposition: UnfocusDisposition.previouslyFocusedChild,
            );
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: TextField(
          controller: _controller,
          focusNode: widget.focusNode,
          onChanged: (value) =>
              ref.read(roomSearchQueryProvider.notifier).query = value,
          decoration: InputDecoration(
            hintText: 'Buscar conversas',
            isDense: true,
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, value, _) => value.text.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Center(
                        widthFactor: 1,
                        child: Text(
                          shortcut,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    )
                  : IconButton(
                      tooltip: 'Limpar busca',
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: _clear,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoomList extends StatelessWidget {
  const _RoomList({
    required this.rooms,
    required this.invites,
    required this.searching,
    required this.selectedId,
    required this.onSelect,
    required this.onAccept,
    required this.onDecline,
  });

  final List<RoomSummary> rooms;
  final List<RoomInvite> invites;
  final bool searching;
  final String? selectedId;
  final ValueChanged<RoomSummary> onSelect;
  final ValueChanged<RoomInvite> onAccept;
  final ValueChanged<RoomInvite> onDecline;

  @override
  Widget build(BuildContext context) {
    if (rooms.isEmpty && invites.isEmpty && searching) {
      return const EmptyState(
        icon: Icons.search_off_rounded,
        title: 'Nenhuma conversa encontrada.',
        hint: 'Tente buscar por outro nome.',
      );
    }

    if (rooms.isEmpty && invites.isEmpty) {
      return const EmptyState(
        icon: Icons.forum_outlined,
        title: 'Você ainda não participa de nenhuma sala.',
        hint: 'Toque em nova conversa para começar.',
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
