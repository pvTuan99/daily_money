import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../data/repositories/category_repository.dart';
import '../data/repositories/wallet_repository.dart';
import '../domain/finance_category.dart';
import '../domain/finance_exception.dart';
import '../domain/wallet.dart';
import '../services/finance_sync_service.dart';

class FinanceSetupScreen extends StatefulWidget {
  const FinanceSetupScreen({super.key});

  @override
  State<FinanceSetupScreen> createState() => _FinanceSetupScreenState();
}

class _FinanceSetupScreenState extends State<FinanceSetupScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  WalletRepository? _walletRepository;
  CategoryRepository? _categoryRepository;
  FinanceSyncService? _syncService;
  bool _showArchived = false;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 3, vsync: this)
      ..addListener(() {
        if (mounted) setState(() {});
      });

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      _walletRepository = WalletRepository(ownerId: userId);
      _categoryRepository = CategoryRepository(ownerId: userId);
      _syncService = FinanceSyncService(ownerId: userId);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncFinance(silent: true);
      });
    }
  }

  Future<void> _syncFinance({bool silent = false}) async {
    final service = _syncService;
    if (service == null || _isSyncing) return;

    setState(() => _isSyncing = true);

    try {
      final result = await service.sync();
      if (!mounted || silent) return;

      if (!result.online) {
        _showMessage(
          'Đang offline. Thay đổi vẫn được lưu trên máy và sẽ đồng bộ sau.',
        );
        return;
      }

      _showMessage(
        'Đã đồng bộ tài chính: ${result.uploaded} tải lên, '
        '${result.downloaded} cập nhật từ cloud.',
      );
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wallets = _walletRepository;
    final categories = _categoryRepository;

    if (wallets == null || categories == null) {
      return const Scaffold(
        backgroundColor: AppTheme.ink,
        body: SafeArea(
          child: Center(
            child: Text(
              'Hãy đăng nhập để quản lý tài chính.',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.ink,
      appBar: AppBar(
        backgroundColor: AppTheme.ink,
        foregroundColor: Colors.white,
        title: const Text(
          'Tài chính',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            onPressed: _isSyncing ? null : () => _syncFinance(),
            tooltip: 'Đồng bộ Firebase',
            icon: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: AppTheme.yellow,
                    ),
                  )
                : const Icon(Icons.cloud_sync_outlined),
          ),
          IconButton(
            onPressed: () {
              setState(() => _showArchived = !_showArchived);
            },
            tooltip: _showArchived ? 'Ẩn mục đã lưu trữ' : 'Hiện mục đã lưu trữ',
            icon: Icon(
              _showArchived
                  ? Icons.inventory_2_rounded
                  : Icons.inventory_2_outlined,
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.yellow,
          labelColor: AppTheme.yellow,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Ví'),
            Tab(text: 'Chi'),
            Tab(text: 'Thu'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _WalletList(
            repository: wallets,
            includeArchived: _showArchived,
            onEdit: _showWalletSheet,
            onArchiveChanged: _setWalletArchived,
          ),
          _CategoryList(
            repository: categories,
            type: CategoryType.expense,
            includeArchived: _showArchived,
            onEdit: (category) => _showCategorySheet(
              CategoryType.expense,
              category: category,
            ),
            onArchiveChanged: _setCategoryArchived,
          ),
          _CategoryList(
            repository: categories,
            type: CategoryType.income,
            includeArchived: _showArchived,
            onEdit: (category) => _showCategorySheet(
              CategoryType.income,
              category: category,
            ),
            onArchiveChanged: _setCategoryArchived,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.yellow,
        foregroundColor: AppTheme.ink,
        onPressed: () {
          switch (_tabController.index) {
            case 0:
              _showWalletSheet();
              break;
            case 1:
              _showCategorySheet(CategoryType.expense);
              break;
            case 2:
              _showCategorySheet(CategoryType.income);
              break;
          }
        },
        icon: const Icon(Icons.add_rounded),
        label: Text(
          switch (_tabController.index) {
            0 => 'Thêm ví',
            1 => 'Danh mục chi',
            _ => 'Danh mục thu',
          },
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  Future<void> _showWalletSheet([FinanceWallet? wallet]) async {
    final repository = _walletRepository;
    if (repository == null) return;

    final nameController = TextEditingController(text: wallet?.name ?? '');
    final balanceController = TextEditingController(
      text: wallet == null ? '' : wallet.initialBalance.toString(),
    );
    var selectedType = wallet?.type ?? WalletType.cash;
    var saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return _FinanceSheet(
              title: wallet == null ? 'Tạo ví mới' : 'Sửa ví',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _FinanceTextField(
                    controller: nameController,
                    label: 'Tên ví',
                    hintText: 'Ví dụ: MB Bank',
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<WalletType>(
                    initialValue: selectedType,
                    dropdownColor: AppTheme.charcoal,
                    iconEnabledColor: Colors.white54,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: _financeInputDecoration(
                      label: 'Loại ví',
                      icon: Icons.wallet_outlined,
                    ),
                    items: WalletType.values
                        .map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Text(type.label),
                          ),
                        )
                        .toList(),
                    onChanged: saving
                        ? null
                        : (value) {
                            if (value == null) return;
                            setSheetState(() => selectedType = value);
                          },
                  ),
                  const SizedBox(height: 12),
                  _FinanceTextField(
                    controller: balanceController,
                    label: 'Số dư ban đầu',
                    hintText: '0',
                    icon: Icons.payments_outlined,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Số dư ban đầu chỉ là điểm xuất phát. Khi có giao dịch, '
                    'số dư thật sẽ được tính từ ledger thay vì sửa tay.',
                    style: TextStyle(
                      color: Colors.white38,
                      height: 1.4,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                            setSheetState(() => saving = true);
                            try {
                              final balance =
                                  _parseMoney(balanceController.text);

                              if (wallet == null) {
                                await repository.createWallet(
                                  name: nameController.text,
                                  type: selectedType,
                                  initialBalance: balance,
                                );
                              } else {
                                await repository.updateWallet(
                                  id: wallet.id,
                                  name: nameController.text,
                                  type: selectedType,
                                  initialBalance: balance,
                                );
                              }

                              if (!sheetContext.mounted) return;
                              Navigator.of(sheetContext).pop();
                            } catch (error) {
                              if (!sheetContext.mounted) return;
                              _showMessage(_financeError(error));
                            } finally {
                              if (sheetContext.mounted) {
                                setSheetState(() => saving = false);
                              }
                            }
                          },
                    child: Text(
                      saving
                          ? 'Đang lưu...'
                          : wallet == null
                              ? 'Tạo ví'
                              : 'Lưu thay đổi',
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    balanceController.dispose();
  }

  Future<void> _showCategorySheet(
    CategoryType type, {
    FinanceCategory? category,
  }) async {
    final repository = _categoryRepository;
    if (repository == null) return;

    final nameController = TextEditingController(text: category?.name ?? '');
    var saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return _FinanceSheet(
              title: category == null
                  ? 'Thêm danh mục ' + type.label.toLowerCase()
                  : 'Đổi tên danh mục',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _FinanceTextField(
                    controller: nameController,
                    label: 'Tên danh mục',
                    hintText: type == CategoryType.expense
                        ? 'Ví dụ: Cà phê'
                        : 'Ví dụ: Việc làm thêm',
                    icon: _categoryIcon(
                      category?.iconKey ?? 'category',
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                            setSheetState(() => saving = true);
                            try {
                              if (category == null) {
                                await repository.createCategory(
                                  name: nameController.text,
                                  type: type,
                                );
                              } else {
                                await repository.renameCategory(
                                  id: category.id,
                                  name: nameController.text,
                                  type: category.type,
                                );
                              }

                              if (!sheetContext.mounted) return;
                              Navigator.of(sheetContext).pop();
                            } catch (error) {
                              if (!sheetContext.mounted) return;
                              _showMessage(_financeError(error));
                            } finally {
                              if (sheetContext.mounted) {
                                setSheetState(() => saving = false);
                              }
                            }
                          },
                    child: Text(
                      saving
                          ? 'Đang lưu...'
                          : category == null
                              ? 'Thêm danh mục'
                              : 'Lưu thay đổi',
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
  }

  Future<void> _setWalletArchived(
    FinanceWallet wallet,
    bool archived,
  ) async {
    try {
      await _walletRepository?.setArchived(wallet.id, archived);
    } catch (error) {
      _showMessage(_financeError(error));
    }
  }

  Future<void> _setCategoryArchived(
    FinanceCategory category,
    bool archived,
  ) async {
    try {
      await _categoryRepository?.setArchived(category.id, archived);
    } catch (error) {
      _showMessage(_financeError(error));
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _WalletList extends StatelessWidget {
  const _WalletList({
    required this.repository,
    required this.includeArchived,
    required this.onEdit,
    required this.onArchiveChanged,
  });

  final WalletRepository repository;
  final bool includeArchived;
  final ValueChanged<FinanceWallet> onEdit;
  final Future<void> Function(FinanceWallet wallet, bool archived)
      onArchiveChanged;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FinanceWallet>>(
      stream: repository.watchWallets(includeArchived: includeArchived),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.yellow),
          );
        }

        final wallets = snapshot.data!;

        if (wallets.isEmpty) {
          return const _EmptyFinanceState(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Chưa có ví',
            subtitle: 'Tạo ví đầu tiên để bắt đầu quản lý tiền.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
          itemCount: wallets.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final wallet = wallets[index];

            return Opacity(
              opacity: wallet.isArchived ? 0.52 : 1,
              child: _FinanceRowCard(
                leading: _FinanceIcon(
                  icon: _walletIcon(wallet.type),
                ),
                title: wallet.name,
                subtitle: wallet.isArchived
                    ? 'Đã lưu trữ'
                    : wallet.type.label +
                        ' · Số dư đầu ' +
                        _formatMoney(wallet.initialBalance),
                onTap: wallet.isArchived ? null : () => onEdit(wallet),
                menu: PopupMenuButton<String>(
                  color: AppTheme.charcoal,
                  iconColor: Colors.white54,
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        onEdit(wallet);
                        break;
                      case 'archive':
                        onArchiveChanged(wallet, true);
                        break;
                      case 'restore':
                        onArchiveChanged(wallet, false);
                        break;
                    }
                  },
                  itemBuilder: (_) => [
                    if (!wallet.isArchived)
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Sửa'),
                      ),
                    PopupMenuItem(
                      value: wallet.isArchived ? 'restore' : 'archive',
                      child: Text(
                        wallet.isArchived ? 'Khôi phục' : 'Lưu trữ',
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({
    required this.repository,
    required this.type,
    required this.includeArchived,
    required this.onEdit,
    required this.onArchiveChanged,
  });

  final CategoryRepository repository;
  final CategoryType type;
  final bool includeArchived;
  final ValueChanged<FinanceCategory> onEdit;
  final Future<void> Function(FinanceCategory category, bool archived)
      onArchiveChanged;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FinanceCategory>>(
      stream: repository.watchCategories(
        type: type,
        includeArchived: includeArchived,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.yellow),
          );
        }

        final categories = snapshot.data!;

        if (categories.isEmpty) {
          return _EmptyFinanceState(
            icon: Icons.category_outlined,
            title: 'Chưa có danh mục ' + type.label.toLowerCase(),
            subtitle: 'Thêm danh mục để giao dịch sau này được phân loại đúng.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
          itemCount: categories.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final category = categories[index];

            return Opacity(
              opacity: category.isArchived ? 0.52 : 1,
              child: _FinanceRowCard(
                leading: _FinanceIcon(
                  icon: _categoryIcon(category.iconKey),
                ),
                title: category.name,
                subtitle: category.isArchived
                    ? 'Đã lưu trữ'
                    : category.isDefault
                        ? 'Danh mục mặc định'
                        : 'Danh mục của bạn',
                onTap: category.isArchived ? null : () => onEdit(category),
                menu: PopupMenuButton<String>(
                  color: AppTheme.charcoal,
                  iconColor: Colors.white54,
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        onEdit(category);
                        break;
                      case 'archive':
                        onArchiveChanged(category, true);
                        break;
                      case 'restore':
                        onArchiveChanged(category, false);
                        break;
                    }
                  },
                  itemBuilder: (_) => [
                    if (!category.isArchived)
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Đổi tên'),
                      ),
                    PopupMenuItem(
                      value: category.isArchived ? 'restore' : 'archive',
                      child: Text(
                        category.isArchived ? 'Khôi phục' : 'Ẩn danh mục',
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _FinanceRowCard extends StatelessWidget {
  const _FinanceRowCard({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.menu,
    this.onTap,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final Widget menu;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.065),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 8, 13),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              menu,
            ],
          ),
        ),
      ),
    );
  }
}

class _FinanceIcon extends StatelessWidget {
  const _FinanceIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        color: AppTheme.yellow,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: AppTheme.ink, size: 23),
    );
  }
}

class _EmptyFinanceState extends StatelessWidget {
  const _EmptyFinanceState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _FinanceIcon(icon: icon),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white54,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinanceSheet extends StatelessWidget {
  const _FinanceSheet({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + bottom),
      decoration: const BoxDecoration(
        color: AppTheme.charcoal,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _FinanceTextField extends StatelessWidget {
  const _FinanceTextField({
    required this.controller,
    required this.label,
    required this.hintText,
    required this.icon,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final IconData icon;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
      ),
      decoration: _financeInputDecoration(
        label: label,
        hintText: hintText,
        icon: icon,
      ),
    );
  }
}

InputDecoration _financeInputDecoration({
  required String label,
  required IconData icon,
  String? hintText,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hintText,
    labelStyle: const TextStyle(color: Colors.white54),
    hintStyle: const TextStyle(color: Colors.white24),
    prefixIcon: Icon(icon, color: Colors.white54),
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.07),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: const BorderSide(color: AppTheme.yellow, width: 1.2),
    ),
  );
}

int _parseMoney(String raw) {
  final normalized = raw
      .trim()
      .replaceAll('.', '')
      .replaceAll(',', '')
      .replaceAll(' ', '');

  if (normalized.isEmpty) return 0;

  final value = int.tryParse(normalized);
  if (value == null) {
    throw const FinanceValidationException(
      'Số dư ban đầu không hợp lệ.',
    );
  }
  return value;
}

String _financeError(Object error) {
  if (error is FinanceValidationException) return error.message;
  return 'Không thể lưu thay đổi lúc này.';
}

String _formatMoney(int amount) {
  final negative = amount < 0;
  final digits = amount.abs().toString();
  final buffer = StringBuffer();

  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(digits[i]);
  }

  return (negative ? '-' : '') + buffer.toString() + ' ₫';
}

IconData _walletIcon(WalletType type) => switch (type) {
      WalletType.cash => Icons.payments_rounded,
      WalletType.bank => Icons.account_balance_rounded,
      WalletType.eWallet => Icons.account_balance_wallet_rounded,
      WalletType.savings => Icons.savings_rounded,
    };

IconData _categoryIcon(String key) => switch (key) {
      'restaurant' => Icons.restaurant_rounded,
      'directions_car' => Icons.directions_car_rounded,
      'home' => Icons.home_rounded,
      'shopping_bag' => Icons.shopping_bag_rounded,
      'sports_esports' => Icons.sports_esports_rounded,
      'health_and_safety' => Icons.health_and_safety_rounded,
      'school' => Icons.school_rounded,
      'receipt_long' => Icons.receipt_long_rounded,
      'work' => Icons.work_rounded,
      'redeem' => Icons.redeem_rounded,
      'laptop_mac' => Icons.laptop_mac_rounded,
      'card_giftcard' => Icons.card_giftcard_rounded,
      'replay' => Icons.replay_rounded,
      'more_horiz' => Icons.more_horiz_rounded,
      _ => Icons.category_rounded,
    };
