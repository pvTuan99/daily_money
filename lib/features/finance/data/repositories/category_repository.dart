import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';

import '../../domain/finance_category.dart';
import '../../domain/finance_exception.dart';
import '../database/app_database.dart' as db;
import 'finance_cloud_repository.dart';

class CategoryRepository {
  CategoryRepository({
    required String ownerId,
    db.AppDatabase? database,
    FinanceCloudRepository? cloudRepository,
  })  : _ownerId = ownerId,
        _db = database ?? db.AppDatabase.instance,
        _cloud = cloudRepository ?? FinanceCloudRepository(ownerId: ownerId);

  final String _ownerId;
  final db.AppDatabase _db;
  final FinanceCloudRepository _cloud;

  Future<void> ensureReady() async {
    await _db.seedDefaultsForUser(_ownerId);
    await _assignMissingCloudIds();
  }

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

  Future<List<FinanceCategory>> getCategories({
    required CategoryType type,
    bool includeArchived = false,
  }) async {
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

    return (await query.get()).map(_mapCategory).toList(growable: false);
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
    final now = DateTime.now();
    final cloudId = _newCloudId('category');

    final id = await _db.into(_db.categories).insert(
          db.CategoriesCompanion.insert(
            ownerId: _ownerId,
            cloudId: Value(cloudId),
            name: cleanName,
            type: type.dbValue,
            iconKey: Value(iconKey),
            sortOrder: Value(maxSort + 10),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

    await _pushById(id);
    return id;
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

    await ensureReady();
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

    await _pushById(id);
  }

  Future<void> setArchived(int id, bool archived) async {
    await ensureReady();

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

    await _pushById(id);
  }

  Future<void> _assignMissingCloudIds() async {
    final rows = await (_db.select(_db.categories)
          ..where(
            (table) =>
                table.ownerId.equals(_ownerId) &
                table.cloudId.isNull(),
          ))
        .get();

    for (final row in rows) {
      final cloudId = row.systemKey ?? _newCloudId('category');
      await (_db.update(_db.categories)
            ..where((table) => table.id.equals(row.id)))
          .write(
        db.CategoriesCompanion(
          cloudId: Value(cloudId),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }

  Future<void> _pushById(int id) async {
    final row = await (_db.select(_db.categories)
          ..where(
            (table) =>
                table.id.equals(id) & table.ownerId.equals(_ownerId),
          )
          ..limit(1))
        .getSingleOrNull();

    if (row == null) return;

    try {
      await _cloud.upsertCategory(_mapCategory(row));
    } on FirebaseException {
      // Keep the local change. The next full sync retries the cloud write.
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
    final cloudId = row.cloudId ?? row.systemKey;
    if (cloudId == null) {
      throw StateError('Category chưa có cloudId.');
    }

    return FinanceCategory(
      id: row.id,
      cloudId: cloudId,
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

String _newCloudId(String prefix) {
  final now = DateTime.now().microsecondsSinceEpoch;
  final random = Random.secure().nextInt(1 << 32).toRadixString(16);
  return '${prefix}_${now}_$random';
}
