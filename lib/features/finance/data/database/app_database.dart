import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

class Wallets extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get ownerId => text()();

  TextColumn get cloudId => text().nullable()();

  TextColumn get systemKey => text().nullable()();

  TextColumn get name => text().withLength(min: 1, max: 60)();

  TextColumn get type => text().withLength(min: 1, max: 24)();

  IntColumn get initialBalance => integer().withDefault(const Constant(0))();

  TextColumn get iconKey =>
      text().withDefault(const Constant('account_balance_wallet'))();

  IntColumn get colorValue => integer().nullable()();

  BoolColumn get isArchived =>
      boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get ownerId => text()();

  TextColumn get cloudId => text().nullable()();

  TextColumn get systemKey => text().nullable()();

  TextColumn get name => text().withLength(min: 1, max: 50)();

  TextColumn get type => text().withLength(min: 1, max: 16)();

  TextColumn get iconKey =>
      text().withDefault(const Constant('category'))();

  IntColumn get colorValue => integer().nullable()();

  BoolColumn get isDefault =>
      boolean().withDefault(const Constant(false))();

  BoolColumn get isArchived =>
      boolean().withDefault(const Constant(false))();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [Wallets, Categories])
final class AppDatabase extends _$AppDatabase {
  AppDatabase._() : super(driftDatabase(name: 'daily_money_finance'));

  static final AppDatabase instance = AppDatabase._();

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (migrator) async {
          await migrator.createAll();
          await _createIndexes();
        },
        onUpgrade: (migrator, from, to) async {
          if (from < 2) {
            await migrator.addColumn(wallets, wallets.cloudId);
            await migrator.addColumn(categories, categories.cloudId);
          }
          await _createIndexes();
        },
      );

  Future<void> _createIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_wallets_owner_archived '
      'ON wallets(owner_id, is_archived)',
    );
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_wallets_owner_cloud '
      'ON wallets(owner_id, cloud_id) WHERE cloud_id IS NOT NULL',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_categories_owner_type_archived '
      'ON categories(owner_id, type, is_archived)',
    );
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_categories_owner_cloud '
      'ON categories(owner_id, cloud_id) WHERE cloud_id IS NOT NULL',
    );
  }

  Future<void> seedDefaultsForUser(String ownerId) async {
    await transaction(() async {
      for (final seed in _defaultWallets) {
        final exists = await (select(wallets)
              ..where(
                (table) =>
                    table.ownerId.equals(ownerId) &
                    table.systemKey.equals(seed.systemKey),
              )
              ..limit(1))
            .getSingleOrNull();

        if (exists == null) {
          await into(wallets).insert(
            WalletsCompanion.insert(
              ownerId: ownerId,
              cloudId: Value(seed.systemKey),
              systemKey: Value(seed.systemKey),
              name: seed.name,
              type: seed.type,
              iconKey: Value(seed.iconKey),
              createdAt: Value(DateTime.fromMillisecondsSinceEpoch(0)),
              updatedAt: Value(DateTime.fromMillisecondsSinceEpoch(0)),
            ),
          );
        } else if (exists.cloudId == null) {
          await (update(wallets)..where((table) => table.id.equals(exists.id)))
              .write(
            WalletsCompanion(
              cloudId: Value(seed.systemKey),
            ),
          );
        }
      }

      for (final seed in _defaultCategories) {
        final exists = await (select(categories)
              ..where(
                (table) =>
                    table.ownerId.equals(ownerId) &
                    table.systemKey.equals(seed.systemKey),
              )
              ..limit(1))
            .getSingleOrNull();

        if (exists == null) {
          await into(categories).insert(
            CategoriesCompanion.insert(
              ownerId: ownerId,
              cloudId: Value(seed.systemKey),
              systemKey: Value(seed.systemKey),
              name: seed.name,
              type: seed.type,
              iconKey: Value(seed.iconKey),
              isDefault: const Value(true),
              sortOrder: Value(seed.sortOrder),
              createdAt: Value(DateTime.fromMillisecondsSinceEpoch(0)),
              updatedAt: Value(DateTime.fromMillisecondsSinceEpoch(0)),
            ),
          );
        } else if (exists.cloudId == null) {
          await (update(categories)
                ..where((table) => table.id.equals(exists.id)))
              .write(
            CategoriesCompanion(
              cloudId: Value(seed.systemKey),
            ),
          );
        }
      }
    });
  }
}

class _WalletSeed {
  const _WalletSeed({
    required this.systemKey,
    required this.name,
    required this.type,
    required this.iconKey,
  });

  final String systemKey;
  final String name;
  final String type;
  final String iconKey;
}

class _CategorySeed {
  const _CategorySeed({
    required this.systemKey,
    required this.name,
    required this.type,
    required this.iconKey,
    required this.sortOrder,
  });

  final String systemKey;
  final String name;
  final String type;
  final String iconKey;
  final int sortOrder;
}

const _defaultWallets = <_WalletSeed>[
  _WalletSeed(
    systemKey: 'wallet_cash',
    name: 'Tiền mặt',
    type: 'cash',
    iconKey: 'payments',
  ),
  _WalletSeed(
    systemKey: 'wallet_bank',
    name: 'Ngân hàng',
    type: 'bank',
    iconKey: 'account_balance',
  ),
];

const _defaultCategories = <_CategorySeed>[
  _CategorySeed(
    systemKey: 'expense_food',
    name: 'Ăn uống',
    type: 'expense',
    iconKey: 'restaurant',
    sortOrder: 10,
  ),
  _CategorySeed(
    systemKey: 'expense_transport',
    name: 'Đi lại',
    type: 'expense',
    iconKey: 'directions_car',
    sortOrder: 20,
  ),
  _CategorySeed(
    systemKey: 'expense_home',
    name: 'Nhà ở',
    type: 'expense',
    iconKey: 'home',
    sortOrder: 30,
  ),
  _CategorySeed(
    systemKey: 'expense_shopping',
    name: 'Mua sắm',
    type: 'expense',
    iconKey: 'shopping_bag',
    sortOrder: 40,
  ),
  _CategorySeed(
    systemKey: 'expense_entertainment',
    name: 'Giải trí',
    type: 'expense',
    iconKey: 'sports_esports',
    sortOrder: 50,
  ),
  _CategorySeed(
    systemKey: 'expense_health',
    name: 'Sức khỏe',
    type: 'expense',
    iconKey: 'health_and_safety',
    sortOrder: 60,
  ),
  _CategorySeed(
    systemKey: 'expense_education',
    name: 'Học tập',
    type: 'expense',
    iconKey: 'school',
    sortOrder: 70,
  ),
  _CategorySeed(
    systemKey: 'expense_bills',
    name: 'Hóa đơn',
    type: 'expense',
    iconKey: 'receipt_long',
    sortOrder: 80,
  ),
  _CategorySeed(
    systemKey: 'expense_other',
    name: 'Khác',
    type: 'expense',
    iconKey: 'more_horiz',
    sortOrder: 90,
  ),
  _CategorySeed(
    systemKey: 'income_salary',
    name: 'Lương',
    type: 'income',
    iconKey: 'work',
    sortOrder: 10,
  ),
  _CategorySeed(
    systemKey: 'income_bonus',
    name: 'Thưởng',
    type: 'income',
    iconKey: 'redeem',
    sortOrder: 20,
  ),
  _CategorySeed(
    systemKey: 'income_freelance',
    name: 'Freelance',
    type: 'income',
    iconKey: 'laptop_mac',
    sortOrder: 30,
  ),
  _CategorySeed(
    systemKey: 'income_gift',
    name: 'Được cho',
    type: 'income',
    iconKey: 'card_giftcard',
    sortOrder: 40,
  ),
  _CategorySeed(
    systemKey: 'income_refund',
    name: 'Hoàn tiền',
    type: 'income',
    iconKey: 'replay',
    sortOrder: 50,
  ),
  _CategorySeed(
    systemKey: 'income_other',
    name: 'Khác',
    type: 'income',
    iconKey: 'more_horiz',
    sortOrder: 60,
  ),
];
