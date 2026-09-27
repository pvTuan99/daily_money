enum WalletType {
  cash,
  bank,
  eWallet,
  savings,
}

extension WalletTypeX on WalletType {
  String get dbValue => switch (this) {
        WalletType.cash => 'cash',
        WalletType.bank => 'bank',
        WalletType.eWallet => 'e_wallet',
        WalletType.savings => 'savings',
      };

  String get label => switch (this) {
        WalletType.cash => 'Tiền mặt',
        WalletType.bank => 'Ngân hàng',
        WalletType.eWallet => 'Ví điện tử',
        WalletType.savings => 'Tiết kiệm',
      };

  static WalletType fromDb(String value) => switch (value) {
        'bank' => WalletType.bank,
        'e_wallet' => WalletType.eWallet,
        'savings' => WalletType.savings,
        _ => WalletType.cash,
      };
}

class FinanceWallet {
  const FinanceWallet({
    required this.id,
    required this.name,
    required this.type,
    required this.initialBalance,
    required this.iconKey,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
    this.systemKey,
    this.colorValue,
  });

  final int id;
  final String? systemKey;
  final String name;
  final WalletType type;
  final int initialBalance;
  final String iconKey;
  final int? colorValue;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;
}
