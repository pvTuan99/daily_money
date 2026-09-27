enum CategoryType {
  expense,
  income,
}

extension CategoryTypeX on CategoryType {
  String get dbValue => switch (this) {
        CategoryType.expense => 'expense',
        CategoryType.income => 'income',
      };

  String get label => switch (this) {
        CategoryType.expense => 'Chi tiêu',
        CategoryType.income => 'Thu nhập',
      };

  static CategoryType fromDb(String value) =>
      value == 'income' ? CategoryType.income : CategoryType.expense;
}

class FinanceCategory {
  const FinanceCategory({
    required this.id,
    required this.name,
    required this.type,
    required this.iconKey,
    required this.isDefault,
    required this.isArchived,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.systemKey,
    this.colorValue,
  });

  final int id;
  final String? systemKey;
  final String name;
  final CategoryType type;
  final String iconKey;
  final int? colorValue;
  final bool isDefault;
  final bool isArchived;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
}
