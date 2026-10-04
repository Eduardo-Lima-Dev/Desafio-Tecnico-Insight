import 'package:app/features/rooms/domain/sync_status.dart';
import 'package:app/features/rooms/state/rooms_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConnectionBanner extends ConsumerWidget {
  const ConnectionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider).value;

    final banner = switch (status) {
      SyncStatus.offline => const _Banner(
        key: ValueKey('offline'),
        message: 'Sem conexão. Tentando reconectar...',
        icon: Icons.wifi_off_rounded,
      ),
      SyncStatus.failed => _Banner(
        key: const ValueKey('failed'),
        message: 'Não foi possível sincronizar.',
        icon: Icons.sync_problem_rounded,
        isError: true,
        onRetry: () => ref.invalidate(syncServiceProvider),
      ),
      _ => const SizedBox.shrink(key: ValueKey('none')),
    };

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: banner,
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.message,
    required this.icon,
    this.isError = false,
    this.onRetry,
    super.key,
  });

  final String message;
  final IconData icon;
  final bool isError;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = isError
        ? scheme.errorContainer
        : scheme.tertiaryContainer;
    final foreground = isError
        ? scheme.onErrorContainer
        : scheme.onTertiaryContainer;

    return Container(
      width: double.infinity,
      color: background,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: TextStyle(color: foreground)),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: const Text('Tentar de novo'),
            ),
        ],
      ),
    );
  }
}
