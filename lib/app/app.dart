import 'package:flutter/material.dart';

import '../features/camera/presentation/camera_screen.dart';
import 'theme/app_theme.dart';

class DailyMoneyApp extends StatelessWidget {
  const DailyMoneyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Daily Money',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const CameraScreen(),
    );
  }
}
