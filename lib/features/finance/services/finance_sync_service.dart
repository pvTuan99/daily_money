import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';

import '../data/database/app_database.dart' as db;
import '../data/repositories/category_repository.dart';
import '../data/repositories/finance_cloud_repository.dart';
import '../data/repositories/wallet_repository.dart';
import '../domain/finance_category.dart';
import '../domain/wallet.dart';

class FinanceSyncService {
  FinanceSyncService({
    required String ownerId,
    db.AppDatabase? database,
    FinanceCloudRepository? cloudRepository,
  })  : _ownerId = ownerId,
        _db = database ?? db.AppDatabase.instance,
        _cloud = cloudRepository ?? FinanceCloudRepository(ownerId: ownerId);

  final String _ownerId;
  final db.AppDatabase _db;
  final FinanceCloudRepository _cloud;

  Future<FinanceSyncResult> sync() async {
    final walletRepository = WalletRepository(
      ownerId: _ownerId,
      database: _db,
      cloudRepository: _cloud,
    );
    final categoryRepository = CategoryRepository(
      ownerId: _ownerId,
      database: _db,
      cloudRepository: _cloud,
    );

    await walletRepository.ensureReady();
    await categoryRepository.ensureReady();

    try {
      final remoteWallets = await _cloud.fetchWallets();
      final remoteCategories = await _cloud.fetchCategories();

      var downloaded = 0;

      downloaded += await _mergeWallets(remoteWallets);
      downloaded += await _mergeCategories(remoteCategories);

      final localWallets = await walletRepository.getWallets(
        includeArchived: true,
      );
      final expenseCategories = await categoryRepository.getCategories(
        type: CategoryType.expense,
        includeArchived: true,
      );
      final incomeCategories = await categoryRepository.getCategories(
        type: CategoryType.income,
        includeArchived: true,
      );

      var uploaded = 0;

      for (final wallet in localWallets) {
        await _cloud.upsertWallet(wallet);
        uploaded++;
      }

      for (final category in [
        ...expenseCategories,
        ...incomeCategories,
      ]) {
        await _cloud.upsertCategory(category);
        uploaded++;
      }

      return FinanceSyncResult(
        online: true,
        uploaded: uploaded,
        downloaded: downloaded,
      );
    } on FirebaseException {
      return const FinanceSyncResult(
        online: false,
        uploaded: 0,
        downloaded: 0,
      );
    }
  }

  Future<int> _mergeWallets(List<CloudWallet> remoteWallets) async {
    var downloaded = 0;

    for (final remote in remoteWallets) {
      final local = await (_db.select(_db.wallets)
            ..where(
              (table) =>
                  table.ownerId.equals(_ownerId) &
                  table.cloudId.equals(remote.cloudId),
            )
            ..limit(1))
          .getSingleOrNull();

      if (local == null) {
        await _db.into(_db.wallets).insert(
              db.WalletsCompanion.insert(
                ownerId: _ownerId,
                cloudId: Value(remote.cloudId),
                systemKey: Value(remote.systemKey),
                name: remote.name,
                type: remote.type,
                initialBalance: Value(remote.initialBalance),
                iconKey: Value(remote.iconKey),
                colorValue: Value(remote.colorValue),
                isArchived: Value(remote.isArchived),
                createdAt: Value(remote.createdAt),
                updatedAt: Value(remote.updatedAt),
              ),
            );
        downloaded++;
        continue;
      }

      if (remote.updatedAt.isAfter(local.updatedAt)) {
        await (_db.update(_db.wallets)
              ..where((table) => table.id.equals(local.id)))
            .write(
          db.WalletsCompanion(
            systemKey: Value(remote.systemKey),
            name: Value(remote.name),
            type: Value(remote.type),
            initialBalance: Value(remote.initialBalance),
            iconKey: Value(remote.iconKey),
            colorValue: Value(remote.colorValue),
            isArchived: Value(remote.isArchived),
            createdAt: Value(remote.createdAt),
            updatedAt: Value(remote.updatedAt),
          ),
        );
        downloaded++;
      }
    }

    return downloaded;
  }

  Future<int> _mergeCategories(
    List<CloudCategory> remoteCategories,
  ) async {
    var downloaded = 0;

    for (final remote in remoteCategories) {
      final local = await (_db.select(_db.categories)
            ..where(
              (table) =>
                  table.ownerId.equals(_ownerId) &
                  table.cloudId.equals(remote.cloudId),
            )
            ..limit(1))
          .getSingleOrNull();

      if (local == null) {
        await _db.into(_db.categories).insert(
              db.CategoriesCompanion.insert(
                ownerId: _ownerId,
                cloudId: Value(remote.cloudId),
                systemKey: Value(remote.systemKey),
                name: remote.name,
                type: remote.type,
                iconKey: Value(remote.iconKey),
                colorValue: Value(remote.colorValue),
                isDefault: Value(remote.isDefault),
                isArchived: Value(remote.isArchived),
                sortOrder: Value(remote.sortOrder),
                createdAt: Value(remote.createdAt),
                updatedAt: Value(remote.updatedAt),
              ),
            );
        downloaded++;
        continue;
      }

      if (remote.updatedAt.isAfter(local.updatedAt)) {
        await (_db.update(_db.categories)
              ..where((table) => table.id.equals(local.id)))
            .write(
          db.CategoriesCompanion(
            systemKey: Value(remote.systemKey),
            name: Value(remote.name),
            type: Value(remote.type),
            iconKey: Value(remote.iconKey),
            colorValue: Value(remote.colorValue),
            isDefault: Value(remote.isDefault),
            isArchived: Value(remote.isArchived),
            sortOrder: Value(remote.sortOrder),
            createdAt: Value(remote.createdAt),
            updatedAt: Value(remote.updatedAt),
          ),
        );
        downloaded++;
      }
    }

    return downloaded;
  }
}

class FinanceSyncResult {
  const FinanceSyncResult({
    required this.online,
    required this.uploaded,
    required this.downloaded,
  });

  final bool online;
  final int uploaded;
  final int downloaded;
}
