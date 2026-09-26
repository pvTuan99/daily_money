import 'dart:io';

import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../spending/presentation/add_spending_sheet.dart';

class MomentPreviewScreen extends StatefulWidget {
  const MomentPreviewScreen({super.key, this.imagePath});

  final String? imagePath;

  @override
  State<MomentPreviewScreen> createState() => _MomentPreviewScreenState();
}

class _MomentPreviewScreenState extends State<MomentPreviewScreen> {
  final _captionController = TextEditingController();
  SpendingDraft? _spending;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _openSpendingSheet() async {
    final result = await showModalBottomSheet<SpendingDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddSpendingSheet(initialValue: _spending),
    );

    if (result != null && mounted) {
      setState(() => _spending = result);
    }
  }

  void _saveMoment() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã lưu khoảnh khắc — phần lưu trữ sẽ được hoàn thiện sau.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.ink,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              child: Row(
                children: [
                  _DarkIconButton(
                    icon: Icons.close_rounded,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  const Text(
                    'khoảnh khắc của bạn',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 46),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                child: Column(
                  children: [
                    _MomentImage(imagePath: widget.imagePath),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: TextField(
                        controller: _captionController,
                        minLines: 1,
                        maxLines: 3,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'viết vài dòng về khoảnh khắc này…',
                          hintStyle: TextStyle(color: Colors.white38),
                          prefixIcon: Icon(
                            Icons.edit_rounded,
                            color: Colors.white60,
                          ),
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SpendingCard(
                      spending: _spending,
                      onTap: _openSpendingSheet,
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _saveMoment,
                      icon: const Icon(Icons.favorite_rounded),
                      label: const Text('Giữ lại khoảnh khắc này'),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'chi tiêu là tùy chọn — kỷ niệm vẫn là điều quan trọng nhất',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DarkIconButton extends StatelessWidget {
  const _DarkIconButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.1),
        foregroundColor: Colors.white,
        minimumSize: const Size(46, 46),
      ),
      icon: Icon(icon),
    );
  }
}

class _MomentImage extends StatelessWidget {
  const _MomentImage({this.imagePath});

  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    final path = imagePath;

    return AspectRatio(
      aspectRatio: 4 / 5,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: path != null && File(path).existsSync()
            ? Image.file(File(path), fit: BoxFit.cover)
            : const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.softBlue,
                      AppTheme.softPink,
                      AppTheme.softYellow,
                    ],
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.image_rounded,
                    size: 72,
                    color: AppTheme.ink,
                  ),
                ),
              ),
      ),
    );
  }
}

class _SpendingCard extends StatelessWidget {
  const _SpendingCard({
    required this.spending,
    required this.onTap,
  });

  final SpendingDraft? spending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final draft = spending;

    return Material(
      color: draft == null
          ? Colors.white.withValues(alpha: 0.08)
          : AppTheme.yellow,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: draft == null
                      ? Colors.white.withValues(alpha: 0.10)
                      : AppTheme.ink,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.payments_rounded,
                  color: draft == null ? Colors.white : AppTheme.yellow,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: draft == null
                    ? const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Thêm chi tiêu',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'không bắt buộc',
                            style: TextStyle(color: Colors.white38),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            draft.amountLabel,
                            style: const TextStyle(
                              color: AppTheme.ink,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${draft.category} · ${draft.wallet}',
                            style: const TextStyle(
                              color: AppTheme.ink,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: draft == null ? Colors.white60 : AppTheme.ink,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
