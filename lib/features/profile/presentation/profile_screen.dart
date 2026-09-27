import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../finance/presentation/finance_setup_screen.dart';
import '../../history/presentation/history_screen.dart';
import '../../moment/data/moment_repository.dart';
import '../../moment/domain/moment.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<List<Moment>> _momentsFuture;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _momentsFuture = MomentRepository.instance.getMoments();
  }

  Future<void> _syncCloud() async {
    if (_isSyncing) return;

    setState(() => _isSyncing = true);

    try {
      final result = await MomentRepository.instance.syncTwoWay();
      if (!mounted) return;

      setState(() {
        _momentsFuture = MomentRepository.instance.getMoments();
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Đồng bộ xong: ${result.uploaded} tải lên, '
              '${result.downloaded} tải về.',
            ),
          ),
        );
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _openFinanceSetup() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FinanceSetupScreen()),
    );
  }

  Future<void> _openHistory() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const HistoryScreen()),
    );

    if (!mounted) return;
    setState(() {
      _momentsFuture = MomentRepository.instance.getMoments();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.ink,
      appBar: AppBar(
        backgroundColor: AppTheme.ink,
        foregroundColor: Colors.white,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Quay lại',
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text(
          'Tôi',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: FutureBuilder<List<Moment>>(
        future: _momentsFuture,
        builder: (context, snapshot) {
          final moments = snapshot.data ?? const <Moment>[];
          final totalSpending = moments.fold<int>(
            0,
            (sum, moment) => sum + (moment.spending?.amount ?? 0),
          );
          final thisMonthCount = moments.where(_isThisMonth).length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
            children: [
              const _ProfileHeader(),
              const SizedBox(height: 22),
              _StatsRow(
                totalMoments: moments.length,
                thisMonthMoments: thisMonthCount,
                totalSpending: totalSpending,
              ),
              const SizedBox(height: 24),
              _SectionCard(
                title: 'Khoảnh khắc',
                children: [
                  _SettingsTile(
                    icon: Icons.photo_library_rounded,
                    title: 'Xem tất cả khoảnh khắc',
                    subtitle: moments.isEmpty
                        ? 'Chưa có khoảnh khắc nào'
                        : '${moments.length} khoảnh khắc đã lưu',
                    onTap: _openHistory,
                  ),
                  const _Divider(),
                  _SettingsTile(
                    icon: _isSyncing
                        ? Icons.sync_rounded
                        : Icons.cloud_done_outlined,
                    title: _isSyncing
                        ? 'Đang đồng bộ...'
                        : 'Đồng bộ hai chiều',
                    subtitle: 'Tải lên và tải metadata từ Firestore về máy',
                    onTap: _isSyncing ? null : _syncCloud,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _SectionCard(
                title: 'Tài chính',
                children: [
                  _SettingsTile(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Ví & danh mục',
                    subtitle: 'SQLite offline + Firebase cho ví và danh mục',
                    onTap: _openFinanceSetup,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _SectionCard(
                title: 'Tài khoản',
                children: [
                  _SettingsTile(
                    icon: Icons.mail_outline_rounded,
                    title: FirebaseAuth.instance.currentUser?.email ??
                        'Tài khoản Daily Money',
                    subtitle: 'Đăng nhập bằng Email/Password',
                  ),
                  const _Divider(),
                  _SettingsTile(
                    icon: Icons.logout_rounded,
                    title: 'Đăng xuất',
                    subtitle: 'Dữ liệu local vẫn được giữ trên thiết bị',
                    onTap: () async {
                      await FirebaseAuth.instance.signOut();
                      if (!context.mounted) return;
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const _SectionCard(
                title: 'Daily Money',
                children: [
                  _SettingsTile(
                    icon: Icons.favorite_rounded,
                    title: 'Phong cách của bạn',
                    subtitle: 'Ảnh trước, chi tiêu sau',
                  ),
                  _Divider(),
                  _SettingsTile(
                    icon: Icons.lock_outline_rounded,
                    title: 'Riêng tư',
                    subtitle: 'Ảnh vẫn nằm trên máy; metadata có thể đồng bộ Firestore',
                  ),
                  _Divider(),
                  _SettingsTile(
                    icon: Icons.info_outline_rounded,
                    title: 'Phiên bản',
                    subtitle: 'Prototype 0.6 · Phase 8A.2',
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  bool _isThisMonth(Moment moment) {
    final now = DateTime.now();
    return moment.createdAt.year == now.year &&
        moment.createdAt.month == now.month;
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 94,
          height: 94,
          decoration: BoxDecoration(
            color: AppTheme.yellow,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 3,
            ),
          ),
          child: const Icon(
            Icons.sentiment_satisfied_alt_rounded,
            color: AppTheme.ink,
            size: 46,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Nhật ký của tôi',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Giữ lại những ngày bình thường theo cách riêng của bạn.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white54,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.totalMoments,
    required this.thisMonthMoments,
    required this.totalSpending,
  });

  final int totalMoments;
  final int thisMonthMoments;
  final int totalSpending;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            value: totalMoments.toString(),
            label: 'Khoảnh khắc',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            value: thisMonthMoments.toString(),
            label: 'Tháng này',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            value: _compactMoney(totalSpending),
            label: 'Chi tiêu',
          ),
        ),
      ],
    );
  }

  static String _compactMoney(int value) {
    if (value >= 1000000) {
      final million = value / 1000000;
      return '${million.toStringAsFixed(million >= 10 ? 0 : 1)}tr';
    }

    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}k';
    }

    return value.toString();
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.yellow,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppTheme.yellow,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppTheme.ink, size: 22),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white38,
              ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 74,
      endIndent: 16,
      color: Colors.white.withValues(alpha: 0.07),
    );
  }
}
