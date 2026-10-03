import 'package:app/features/session/domain/auth_state.dart';
import 'package:app/features/session/state/session_providers.dart';
import 'package:app/features/session/ui/home_page.dart';
import 'package:app/features/session/ui/login_page.dart';
import 'package:app/features/session/ui/splash_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SessionGate extends ConsumerWidget {
  const SessionGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(sessionControllerProvider);

    return auth.when(
      loading: () => const SplashPage(),
      error: (_, _) => const LoginPage(),
      data: (state) => switch (state) {
        Unauthenticated() => const LoginPage(),
        Authenticated(:final session) => HomePage(session: session),
      },
    );
  }
}
