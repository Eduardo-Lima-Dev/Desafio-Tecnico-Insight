import 'package:app/features/conversations/ui/new_conversation_dialog.dart';
import 'package:app/features/rooms/state/rooms_providers.dart';
import 'package:app/features/rooms/ui/connection_banner.dart';
import 'package:app/features/rooms/ui/conversation_panel.dart';
import 'package:app/features/rooms/ui/room_list_panel.dart';
import 'package:app/features/rooms/ui/user_footer.dart';
import 'package:app/features/session/domain/session.dart';
import 'package:app/features/session/state/session_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _wideBreakpoint = 720.0;
const _sidebarWidth = 340.0;
const _transition = Duration(milliseconds: 220);

class HomePage extends ConsumerStatefulWidget {
  const HomePage({required this.session, super.key});

  final Session session;

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  void _focusSearch() {
    if (_searchFocus.context?.mounted ?? false) {
      _searchFocus.requestFocus();
      return;
    }
    ref.read(selectedRoomIdProvider.notifier).select(null);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  Future<void> _newConversation() async {
    final roomId = await showNewConversationDialog(context);
    if (roomId != null) {
      ref.read(selectedRoomIdProvider.notifier).select(roomId);
    }
  }

  void _closeConversation() {
    ref.read(selectedRoomIdProvider.notifier).select(null);
  }

  @override
  Widget build(BuildContext context) {
    ref
      ..watch(roomsProvider)
      ..watch(syncStatusProvider);
    final selectedId = ref.watch(selectedRoomIdProvider);
    final scheme = Theme.of(context).colorScheme;

    final sidebar = Column(
      children: [
        Expanded(
          child: RoomListPanel(
            searchFocusNode: _searchFocus,
            onNewConversation: _newConversation,
          ),
        ),
        UserFooter(
          session: widget.session,
          onLogout: () => ref.read(sessionControllerProvider.notifier).logout(),
        ),
      ],
    );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
            _focusSearch,
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            _focusSearch,
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true):
            _newConversation,
        const SingleActivator(LogicalKeyboardKey.keyN, control: true):
            _newConversation,
        const SingleActivator(LogicalKeyboardKey.escape): _closeConversation,
      },
      child: FocusScope(
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= _wideBreakpoint;

            final Widget content;
            if (wide) {
              content = Row(
                children: [
                  SizedBox(
                    width: _sidebarWidth,
                    child: ColoredBox(
                      color: scheme.surfaceContainerLow,
                      child: sidebar,
                    ),
                  ),
                  Expanded(
                    child: _Transition(
                      child: ConversationPanel(
                        key: ValueKey(selectedId),
                        roomId: selectedId,
                      ),
                    ),
                  ),
                ],
              );
            } else {
              content = _Transition(
                child: selectedId == null
                    ? KeyedSubtree(key: const ValueKey('list'), child: sidebar)
                    : ConversationPanel(
                        key: ValueKey(selectedId),
                        roomId: selectedId,
                        onBack: _closeConversation,
                      ),
              );
            }

            return Scaffold(
              body: Column(
                children: [
                  const ConnectionBanner(),
                  Expanded(child: content),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Transition extends StatelessWidget {
  const _Transition({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: _transition,
      switchInCurve: Curves.easeOut,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.03, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
