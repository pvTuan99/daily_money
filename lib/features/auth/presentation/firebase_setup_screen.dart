import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';

class FirebaseSetupScreen extends StatelessWidget {
  const FirebaseSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.ink,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: const BoxDecoration(
                    color: AppTheme.yellow,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.local_fire_department_rounded,
                    color: AppTheme.ink,
                    size: 38,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Cần kết nối Firebase',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Phần đăng nhập đã sẵn sàng. Bây giờ chỉ cần cấu hình dự án Firebase cho Daily Money trên máy của bạn.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white60,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 26),
                const _SetupStep(
                  number: '1',
                  text: 'Tạo hoặc chọn một Firebase project.',
                ),
                const _SetupStep(
                  number: '2',
                  text: 'Chạy: dart pub global activate flutterfire_cli',
                ),
                const _SetupStep(
                  number: '3',
                  text: 'Trong thư mục project chạy: flutterfire configure',
                ),
                const _SetupStep(
                  number: '4',
                  text: 'Trong Firebase Authentication, bật Email/Password.',
                ),
                const SizedBox(height: 20),
                const Text(
                  'Sau khi cấu hình xong, khởi động lại app.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.yellow,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SetupStep extends StatelessWidget {
  const _SetupStep({
    required this.number,
    required this.text,
  });

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: AppTheme.yellow,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                number,
                style: const TextStyle(
                  color: AppTheme.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
