import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  static const _moments = [
    _MomentMock(
      time: 'Today · 18:42',
      caption: 'Dinner after a long day ✨',
      amount: '85.000 ₫',
      emoji: '🍜',
      colors: [Color(0xFFFFD7C2), Color(0xFFFFF0B8)],
    ),
    _MomentMock(
      time: 'Today · 14:10',
      caption: 'Coffee + bug fixing',
      amount: '32.000 ₫',
      emoji: '☕',
      colors: [Color(0xFFE4DBFF), Color(0xFFCDEBFF)],
    ),
    _MomentMock(
      time: 'Yesterday · 20:03',
      caption: 'Just a nice sky',
      emoji: '🌆',
      colors: [Color(0xFFCCD7FF), Color(0xFFFFCDEB)],
    ),
    _MomentMock(
      time: 'Yesterday · 12:21',
      caption: 'Quick lunch',
      amount: '45.000 ₫',
      emoji: '🥗',
      colors: [Color(0xFFD9FFC9), Color(0xFFFFE8A8)],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_horiz_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
            sliver: SliverToBoxAdapter(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      'Your\nmoments',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.lime,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Text(
                      '4 this week',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _MomentCard(moment: _moments[index]),
                childCount: _moments.length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.72,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MomentCard extends StatelessWidget {
  const _MomentCard({required this.moment});

  final _MomentMock moment;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: moment.colors,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              moment.time,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.ink.withValues(alpha: 0.5),
              ),
            ),
            const Spacer(),
            Text(moment.emoji, style: const TextStyle(fontSize: 42)),
            const SizedBox(height: 10),
            Text(
              moment.caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                height: 1.15,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (moment.amount != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  moment.amount!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MomentMock {
  const _MomentMock({
    required this.time,
    required this.caption,
    required this.emoji,
    required this.colors,
    this.amount,
  });

  final String time;
  final String caption;
  final String emoji;
  final String? amount;
  final List<Color> colors;
}
