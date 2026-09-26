import 'dart:io';

import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../spending/presentation/add_spending_sheet.dart';
import '../data/moment_repository.dart';
import '../domain/moment.dart';

class MomentDetailScreen extends StatefulWidget {
  const MomentDetailScreen({
    super.key,
    required this.moment,
  });

  final Moment moment;

  @override
  State<MomentDetailScreen> createState() => _MomentDetailScreenState();
}

class _MomentDetailScreenState extends State<MomentDetailScreen> {
  late Moment _moment;
  late final TextEditingController _captionController;
  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _moment = widget.moment;
    _captionController = TextEditingController(text: _moment.caption);
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _editSpending() async {
    final current = _moment.spending;
    final result = await showModalBottomSheet<SpendingDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddSpendingSheet(
        initialValue: current == null
            ? null
            : SpendingDraft(
                amount: current.amount,
                category: current.category,
                wallet: current.wallet,
                note: current.note,
              ),
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      _moment = _moment.copyWith(
        spending: MomentSpending(
          amount: result.amount,
          category: result.category,
          wallet: result.wallet,
          note: result.note,
        ),
      );
    });
  }

  Future<void> _saveChanges() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final updated = _moment.copyWith(
        caption: _captionController.text.trim(),
      );

      await MomentRepository.instance.updateMoment(updated);

      if (!mounted) return;

      setState(() {
        _moment = updated;
        _isEditing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã cập nhật khoảnh khắc.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể cập nhật khoảnh khắc lúc này.')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _removeSpending() async {
    setState(() {
      _moment = _moment.copyWith(clearSpending: true);
    });

    await _saveChanges();
  }

  Future<void> _deleteMoment() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa khoảnh khắc này?'),
        content: const Text(
          'Ảnh và thông tin đã lưu trên thiết bị sẽ bị xóa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    try {
      await MomentRepository.instance.deleteMoment(_moment);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể xóa khoảnh khắc lúc này.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final spending = _moment.spending;

    return Scaffold(
      backgroundColor: AppTheme.ink,
      appBar: AppBar(
        backgroundColor: AppTheme.ink,
        foregroundColor: Colors.white,
        title: const Text(
          'Chi tiết khoảnh khắc',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: _isEditing ? 'Lưu' : 'Chỉnh sửa',
            onPressed: _isSaving
                ? null
                : () {
                    if (_isEditing) {
                      _saveChanges();
                    } else {
                      setState(() => _isEditing = true);
                    }
                  },
            icon: Icon(_isEditing ? Icons.check_rounded : Icons.edit_rounded),
          ),
          PopupMenuButton<String>(
            color: AppTheme.charcoal,
            iconColor: Colors.white,
            onSelected: (value) {
              if (value == 'delete') _deleteMoment();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'delete',
                child: Text(
                  'Xóa khoảnh khắc',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          Hero(
            tag: 'moment-${_moment.id}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(36),
              child: AspectRatio(
                aspectRatio: 4 / 5,
                child: Image.file(
                  File(_moment.imagePath),
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, __, ___) => const ColoredBox(
                    color: Color(0xFF292929),
                    child: Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white54,
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            _formatDate(_moment.createdAt),
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          if (_isEditing)
            TextField(
              controller: _captionController,
              minLines: 1,
              maxLines: 4,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                hintText: 'Viết vài dòng về khoảnh khắc này…',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(
                    color: AppTheme.yellow,
                    width: 1.2,
                  ),
                ),
              ),
            )
          else
            Text(
              _moment.caption.isEmpty
                  ? 'Không có ghi chú cho khoảnh khắc này.'
                  : _moment.caption,
              style: TextStyle(
                color: _moment.caption.isEmpty ? Colors.white38 : Colors.white,
                fontSize: 21,
                height: 1.28,
                fontWeight: FontWeight.w800,
              ),
            ),
          const SizedBox(height: 18),
          _MoneyCard(
            spending: spending,
            isEditing: _isEditing,
            onTap: _editSpending,
            onRemove: _removeSpending,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year} · $hour:$minute';
  }
}

class _MoneyCard extends StatelessWidget {
  const _MoneyCard({
    required this.spending,
    required this.isEditing,
    required this.onTap,
    required this.onRemove,
  });

  final MomentSpending? spending;
  final bool isEditing;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final value = spending;

    return Material(
      color: value == null
          ? Colors.white.withValues(alpha: 0.07)
          : AppTheme.yellow,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: isEditing ? onTap : null,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: value == null
                      ? Colors.white.withValues(alpha: 0.1)
                      : AppTheme.ink,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.payments_rounded,
                  color: value == null ? Colors.white54 : AppTheme.yellow,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: value == null
                    ? const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Không có chi tiêu',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Bật chỉnh sửa để thêm',
                            style: TextStyle(color: Colors.white38),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatAmount(value.amount),
                            style: const TextStyle(
                              color: AppTheme.ink,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${value.category} · ${value.wallet}',
                            style: const TextStyle(
                              color: AppTheme.ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (value.note.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              value.note,
                              style: TextStyle(
                                color: AppTheme.ink.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
              if (isEditing && value != null)
                IconButton(
                  onPressed: onRemove,
                  tooltip: 'Xóa chi tiêu',
                  icon: const Icon(Icons.close_rounded),
                  color: AppTheme.ink,
                )
              else if (isEditing)
                const Icon(Icons.add_rounded, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatAmount(int amount) {
    final digits = amount.toString();
    final buffer = StringBuffer();

    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }

    return '${buffer.toString()} ₫';
  }
}
