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
      const SnackBar(content: Text('Moment saved — local storage comes next.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                  const Spacer(),
                  Text('New moment', style: textTheme.titleLarge),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _MomentImage(imagePath: widget.imagePath),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _captionController,
                      minLines: 1,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'What happened?',
                        prefixIcon: Icon(Icons.edit_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SpendingCard(
                      spending: _spending,
                      onTap: _openSpendingSheet,
                    ),
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: _saveMoment,
                      icon: const Icon(Icons.auto_awesome_rounded),
                      label: const Text('Save this moment'),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Money is optional. Your moment is still a moment without it.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppTheme.ink.withValues(alpha: 0.52),
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
                      AppTheme.softLavender,
                      AppTheme.softPeach,
                      AppTheme.lime,
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
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: AppTheme.lime,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.payments_rounded),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: draft == null
                    ? const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add spending',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          SizedBox(height: 3),
                          Text('Optional · keep the memory first'),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            draft.amountLabel,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text('${draft.category} · ${draft.wallet}'),
                        ],
                      ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
