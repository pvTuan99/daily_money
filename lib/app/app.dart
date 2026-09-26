import 'package:flutter/material.dart';

import '../features/auth/auth_gate.dart';
import '../features/auth/presentation/firebase_setup_screen.dart';
import 'theme/app_theme.dart';

class DailyMoneyApp extends StatelessWidget {
  const DailyMoneyApp({
    super.key,
    this.firebaseReady = false,
  });

  final bool firebaseReady;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nhật Ký Hôm Nay',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: firebaseReady
          ? const AuthGate()
          : const FirebaseSetupScreen(),
    );
  }
}
