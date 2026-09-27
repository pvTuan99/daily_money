import 'package:drift/drift.dart';

import '../../domain/finance_category.dart';
import '../../domain/finance_exception.dart';
import '../database/app_database.dart' as db;

class CategoryRepository {
  CategoryRepository({
    required String ownerId,
    db.AppDatabase? database,
  })  : _ownerId = ownerId,
        _db = database ?? db.AppDatabase.instance;

  final String _ownerId;
  final db.AppDatabase _db;

  Future<void> ensureReady() => _db.seedDefaultsForUser(_ownerId);

  Stream<List<FinanceCategory>> watchCategories({
    required CategoryType type,
    bool includeArchived = false,
  }) async* {
    await ensureReady();

    final query = _db.select(_db.categories)
      ..where((table) {
        final base = table.ownerId.equals(_ownerId) &
            table.type.equals(type.dbValue);
        if (includeArchived) return base;
        return base & table.isArchived.equals(false);
      })
      ..orderBy([
        (table) => OrderingTerm.asc(table.isArchived),
        (table) => OrderingTerm.asc(table.sortOrder),
        (table) => OrderingTerm.asc(table.name),
      ]);

    yield* query.watch().map(
          (rows) => rows.map(_mapCategory).toList(growable: false),
        );
  }

  Future<int> createCategory({
    required String name,
    required CategoryType type,
    String iconKey = 'category',
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw const FinanceValidationException(
        'Tên danh mục không được để trống.',
      );
    }

    await ensureReady();
    await _ensureUniqueName(cleanName, type);

    final maxSort = await _maxSortOrder(type);

    return _db.into(_db.categories).insert(
          db.CategoriesCompanion.insert(
            ownerId: _ownerId,
            name: cleanName,
            type: type.dbValue,
            iconKey: Value(iconKey),
            sortOrder: Value(maxSort + 10),
          ),
        );
  }

  Future<void> renameCategory({
    required int id,
    required String name,
    required CategoryType type,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw const FinanceValidationException(
        'Tên danh mục không được để trống.',
      );
    }

    await _ensureUniqueName(cleanName, type, exceptId: id);

    final affected = await (_db.update(_db.categories)
          ..where(
            (table) =>
                table.id.equals(id) & table.ownerId.equals(_ownerId),
          ))
        .write(
      db.CategoriesCompanion(
        name: Value(cleanName),
        updatedAt: Value(DateTime.now()),
      ),
    );

    if (affected == 0) {
      throw const FinanceValidationException(
        'Không tìm thấy danh mục để cập nhật.',
      );
    }
  }

  Future<void> setArchived(int id, bool archived) async {
    final affected = await (_db.update(_db.categories)
          ..where(
            (table) =>
                table.id.equals(id) & table.ownerId.equals(_ownerId),
          ))
        .write(
      db.CategoriesCompanion(
        isArchived: Value(archived),
        updatedAt: Value(DateTime.now()),
      ),
    );

    if (affected == 0) {
      throw const FinanceValidationException('Không tìm thấy danh mục.');
    }
  }

  Future<void> _ensureUniqueName(
    String name,
    CategoryType type, {
    int? exceptId,
  }) async {
    final rows = await (_db.select(_db.categories)
          ..where(
            (table) =>
                table.ownerId.equals(_ownerId) &
                table.type.equals(type.dbValue) &
                table.isArchived.equals(false),
          ))
        .get();

    final normalized = name.toLowerCase();
    final duplicated = rows.any(
      (row) =>
          row.id != exceptId &&
          row.name.trim().toLowerCase() == normalized,
    );

    if (duplicated) {
      throw const FinanceValidationException(
        'Danh mục này đã tồn tại.',
      );
    }
  }

  Future<int> _maxSortOrder(CategoryType type) async {
    final rows = await (_db.select(_db.categories)
          ..where(
            (table) =>
                table.ownerId.equals(_ownerId) &
                table.type.equals(type.dbValue),
          ))
        .get();

    var maxValue = 0;
    for (final row in rows) {
      if (row.sortOrder > maxValue) maxValue = row.sortOrder;
    }
    return maxValue;
  }

  FinanceCategory _mapCategory(db.Category row) {
    return FinanceCategory(
      id: row.id,
      systemKey: row.systemKey,
      name: row.name,
      type: CategoryTypeX.fromDb(row.type),
      iconKey: row.iconKey,
      colorValue: row.colorValue,
      isDefault: row.isDefault,
      isArchived: row.isArchived,
      sortOrder: row.sortOrder,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
