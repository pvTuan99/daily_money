import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';

import '../../domain/finance_exception.dart';
import '../../domain/wallet.dart';
import '../database/app_database.dart' as db;
import 'finance_cloud_repository.dart';

class WalletRepository {
  WalletRepository({
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

  Stream<List<FinanceWallet>> watchWallets({
    bool includeArchived = false,
  }) async* {
    await ensureReady();

    final query = _db.select(_db.wallets)
      ..where((table) {
        final owner = table.ownerId.equals(_ownerId);
        if (includeArchived) return owner;
        return owner & table.isArchived.equals(false);
      })
      ..orderBy([
        (table) => OrderingTerm.asc(table.isArchived),
        (table) => OrderingTerm.asc(table.createdAt),
      ]);

    yield* query.watch().map(
          (rows) => rows.map(_mapWallet).toList(growable: false),
        );
  }

  Future<List<FinanceWallet>> getWallets({
    bool includeArchived = false,
  }) async {
    await ensureReady();

    final query = _db.select(_db.wallets)
      ..where((table) {
        final owner = table.ownerId.equals(_ownerId);
        if (includeArchived) return owner;
        return owner & table.isArchived.equals(false);
      })
      ..orderBy([
        (table) => OrderingTerm.asc(table.isArchived),
        (table) => OrderingTerm.asc(table.createdAt),
      ]);

    return (await query.get()).map(_mapWallet).toList(growable: false);
  }

  Future<int> createWallet({
    required String name,
    required WalletType type,
    int initialBalance = 0,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw const FinanceValidationException('Tên ví không được để trống.');
    }

    await ensureReady();
    await _ensureUniqueName(cleanName);

    final now = DateTime.now();
    final cloudId = _newCloudId('wallet');

    final id = await _db.into(_db.wallets).insert(
          db.WalletsCompanion.insert(
            ownerId: _ownerId,
            cloudId: Value(cloudId),
            name: cleanName,
            type: type.dbValue,
            initialBalance: Value(initialBalance),
            iconKey: Value(_iconForType(type)),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

    await _pushById(id);
    return id;
  }

  Future<void> updateWallet({
    required int id,
    required String name,
    required WalletType type,
    required int initialBalance,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw const FinanceValidationException('Tên ví không được để trống.');
    }

    await ensureReady();
    await _ensureUniqueName(cleanName, exceptId: id);

    final affected = await (_db.update(_db.wallets)
          ..where(
            (table) =>
                table.id.equals(id) & table.ownerId.equals(_ownerId),
          ))
        .write(
      db.WalletsCompanion(
        name: Value(cleanName),
        type: Value(type.dbValue),
        initialBalance: Value(initialBalance),
        iconKey: Value(_iconForType(type)),
        updatedAt: Value(DateTime.now()),
      ),
    );

    if (affected == 0) {
      throw const FinanceValidationException('Không tìm thấy ví để cập nhật.');
    }

    await _pushById(id);
  }

  Future<void> setArchived(int id, bool archived) async {
    await ensureReady();

    final affected = await (_db.update(_db.wallets)
          ..where(
            (table) =>
                table.id.equals(id) & table.ownerId.equals(_ownerId),
          ))
        .write(
      db.WalletsCompanion(
        isArchived: Value(archived),
        updatedAt: Value(DateTime.now()),
      ),
    );

    if (affected == 0) {
      throw const FinanceValidationException('Không tìm thấy ví.');
    }

    await _pushById(id);
  }

  Future<void> _assignMissingCloudIds() async {
    final rows = await (_db.select(_db.wallets)
          ..where(
            (table) =>
                table.ownerId.equals(_ownerId) &
                table.cloudId.isNull(),
          ))
        .get();

    for (final row in rows) {
      final cloudId = row.systemKey ?? _newCloudId('wallet');
      await (_db.update(_db.wallets)..where((table) => table.id.equals(row.id)))
          .write(
        db.WalletsCompanion(
          cloudId: Value(cloudId),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }

  Future<void> _pushById(int id) async {
    final row = await (_db.select(_db.wallets)
          ..where(
            (table) =>
                table.id.equals(id) & table.ownerId.equals(_ownerId),
          )
          ..limit(1))
        .getSingleOrNull();

    if (row == null) return;

    try {
      await _cloud.upsertWallet(_mapWallet(row));
    } on FirebaseException {
      // Local SQLite remains the immediate source while offline.
      // A later full sync retries this write.
    }
  }

  Future<void> _ensureUniqueName(
    String name, {
    int? exceptId,
  }) async {
    final rows = await (_db.select(_db.wallets)
          ..where(
            (table) =>
                table.ownerId.equals(_ownerId) &
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
        'Bạn đã có một ví đang hoạt động với tên này.',
      );
    }
  }

  FinanceWallet _mapWallet(db.Wallet row) {
    final cloudId = row.cloudId ?? row.systemKey;
    if (cloudId == null) {
      throw StateError('Wallet chưa có cloudId.');
    }

    return FinanceWallet(
      id: row.id,
      cloudId: cloudId,
      systemKey: row.systemKey,
      name: row.name,
      type: WalletTypeX.fromDb(row.type),
      initialBalance: row.initialBalance,
      iconKey: row.iconKey,
      colorValue: row.colorValue,
      isArchived: row.isArchived,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  String _iconForType(WalletType type) => switch (type) {
        WalletType.cash => 'payments',
        WalletType.bank => 'account_balance',
        WalletType.eWallet => 'account_balance_wallet',
        WalletType.savings => 'savings',
      };
}

String _newCloudId(String prefix) {
  final now = DateTime.now().microsecondsSinceEpoch;
  final random = Random.secure().nextInt(1 << 32).toRadixString(16);
  return '${prefix}_${now}_$random';
}
