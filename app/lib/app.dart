import 'package:app/features/session/ui/session_gate.dart';
import 'package:app/theme/app_theme.dart';
import 'package:flutter/material.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Insight Matrix',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const SessionGate(),
    );
  }
}
