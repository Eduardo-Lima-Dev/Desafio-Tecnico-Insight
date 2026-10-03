import 'package:app/features/rooms/state/rooms_providers.dart';
import 'package:app/features/rooms/ui/connection_banner.dart';
import 'package:app/features/rooms/ui/conversation_panel.dart';
import 'package:app/features/rooms/ui/room_list_panel.dart';
import 'package:app/features/rooms/ui/user_footer.dart';
import 'package:app/features/session/domain/session.dart';
import 'package:app/features/session/state/session_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _wideBreakpoint = 720.0;

class HomePage extends ConsumerWidget {
  const HomePage({required this.session, super.key});

  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref
      ..watch(roomsProvider)
      ..watch(syncStatusProvider);
    final selectedId = ref.watch(selectedRoomIdProvider);

    final sidebar = Column(
      children: [
        const Expanded(child: RoomListPanel()),
        UserFooter(
          session: session,
          onLogout: () => ref.read(sessionControllerProvider.notifier).logout(),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _wideBreakpoint;

        if (wide) {
          return Scaffold(
            body: Column(
              children: [
                const ConnectionBanner(),
                Expanded(
                  child: Row(
                    children: [
                      SizedBox(width: 340, child: sidebar),
                      const VerticalDivider(width: 1),
                      const Expanded(child: ConversationPanel()),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          body: Column(
            children: [
              const ConnectionBanner(),
              Expanded(
                child: selectedId == null
                    ? sidebar
                    : ConversationPanel(
                        onBack: () => ref
                            .read(selectedRoomIdProvider.notifier)
                            .select(null),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
