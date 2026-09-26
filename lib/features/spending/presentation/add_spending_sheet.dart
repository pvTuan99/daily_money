import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';

class SpendingDraft {
  const SpendingDraft({
    required this.amount,
    required this.category,
    required this.wallet,
    this.note = '',
  });

  final int amount;
  final String category;
  final String wallet;
  final String note;

  String get amountLabel {
    final digits = amount.toString();
    final buffer = StringBuffer();

    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(digits[i]);
    }

    return '${buffer.toString()} ₫';
  }
}

class AddSpendingSheet extends StatefulWidget {
  const AddSpendingSheet({super.key, this.initialValue});

  final SpendingDraft? initialValue;

  @override
  State<AddSpendingSheet> createState() => _AddSpendingSheetState();
}

class _AddSpendingSheetState extends State<AddSpendingSheet> {
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late String _category;
  late String _wallet;

  static const _categories = [
    ('Food', '🍜'),
    ('Coffee', '☕'),
    ('Travel', '🛵'),
    ('Shopping', '🛍️'),
    ('Fun', '🎮'),
  ];

  static const _wallets = ['Cash', 'Bank'];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialValue;
    _amountController = TextEditingController(
      text: initial?.amount == null ? '' : initial!.amount.toString(),
    );
    _noteController = TextEditingController(text: initial?.note ?? '');
    _category = initial?.category ?? _categories.first.$1;
    _wallet = initial?.wallet ?? _wallets.first;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _save() {
    final raw = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final amount = int.tryParse(raw);

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an amount first.')),
      );
      return;
    }

    Navigator.of(context).pop(
      SpendingDraft(
        amount: amount,
        category: _category,
        wallet: _wallet,
        note: _noteController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
      decoration: const BoxDecoration(
        color: AppTheme.paper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppTheme.ink.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Add spending',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Attach money to this moment — only if it belongs here.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.ink.withValues(alpha: 0.55),
                    ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                ),
                decoration: const InputDecoration(
                  hintText: '0',
                  suffixText: '₫',
                  prefixIcon: Icon(Icons.payments_rounded),
                ),
              ),
              const SizedBox(height: 18),
              const _SectionLabel('Category'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in _categories)
                    ChoiceChip(
                      selected: _category == item.$1,
                      onSelected: (_) => setState(() => _category = item.$1),
                      label: Text('${item.$2}  ${item.$1}'),
                      selectedColor: AppTheme.lime,
                      side: BorderSide.none,
                    ),
                ],
              ),
              const SizedBox(height: 18),
              const _SectionLabel('Wallet'),
              const SizedBox(height: 10),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'Cash',
                    icon: Icon(Icons.wallet_rounded),
                    label: Text('Cash'),
                  ),
                  ButtonSegment(
                    value: 'Bank',
                    icon: Icon(Icons.account_balance_rounded),
                    label: Text('Bank'),
                  ),
                ],
                selected: {_wallet},
                onSelectionChanged: (value) {
                  setState(() => _wallet = value.first);
                },
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Note (optional)',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _save,
                child: const Text('Attach spending'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
