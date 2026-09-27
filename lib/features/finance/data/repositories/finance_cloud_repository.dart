import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/finance_category.dart';
import '../../domain/wallet.dart';

class FinanceCloudRepository {
  FinanceCloudRepository({
    required String ownerId,
    FirebaseFirestore? firestore,
  })  : _ownerId = ownerId,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final String _ownerId;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _wallets =>
      _firestore.collection('users').doc(_ownerId).collection('wallets');

  CollectionReference<Map<String, dynamic>> get _categories =>
      _firestore.collection('users').doc(_ownerId).collection('categories');

  Future<void> upsertWallet(FinanceWallet wallet) async {
    await _wallets.doc(wallet.cloudId).set(
      {
        'cloudId': wallet.cloudId,
        'systemKey': wallet.systemKey,
        'name': wallet.name,
        'type': wallet.type.dbValue,
        'initialBalance': wallet.initialBalance,
        'iconKey': wallet.iconKey,
        'colorValue': wallet.colorValue,
        'isArchived': wallet.isArchived,
        'createdAt': Timestamp.fromDate(wallet.createdAt),
        'updatedAt': Timestamp.fromDate(wallet.updatedAt),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> upsertCategory(FinanceCategory category) async {
    await _categories.doc(category.cloudId).set(
      {
        'cloudId': category.cloudId,
        'systemKey': category.systemKey,
        'name': category.name,
        'type': category.type.dbValue,
        'iconKey': category.iconKey,
        'colorValue': category.colorValue,
        'isDefault': category.isDefault,
        'isArchived': category.isArchived,
        'sortOrder': category.sortOrder,
        'createdAt': Timestamp.fromDate(category.createdAt),
        'updatedAt': Timestamp.fromDate(category.updatedAt),
      },
      SetOptions(merge: true),
    );
  }

  Future<List<CloudWallet>> fetchWallets() async {
    final snapshot = await _wallets.get();

    return snapshot.docs
        .map((doc) => CloudWallet.fromDocument(doc))
        .toList(growable: false);
  }

  Future<List<CloudCategory>> fetchCategories() async {
    final snapshot = await _categories.get();

    return snapshot.docs
        .map((doc) => CloudCategory.fromDocument(doc))
        .toList(growable: false);
  }
}

class CloudWallet {
  const CloudWallet({
    required this.cloudId,
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

  final String cloudId;
  final String? systemKey;
  final String name;
  final String type;
  final int initialBalance;
  final String iconKey;
  final int? colorValue;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory CloudWallet.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};

    return CloudWallet(
      cloudId: data['cloudId'] as String? ?? doc.id,
      systemKey: data['systemKey'] as String?,
      name: data['name'] as String? ?? 'Ví',
      type: data['type'] as String? ?? 'cash',
      initialBalance: (data['initialBalance'] as num?)?.toInt() ?? 0,
      iconKey: data['iconKey'] as String? ?? 'account_balance_wallet',
      colorValue: (data['colorValue'] as num?)?.toInt(),
      isArchived: data['isArchived'] as bool? ?? false,
      createdAt: _dateFrom(data['createdAt']),
      updatedAt: _dateFrom(data['updatedAt']),
    );
  }
}

class CloudCategory {
  const CloudCategory({
    required this.cloudId,
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

  final String cloudId;
  final String? systemKey;
  final String name;
  final String type;
  final String iconKey;
  final int? colorValue;
  final bool isDefault;
  final bool isArchived;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory CloudCategory.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};

    return CloudCategory(
      cloudId: data['cloudId'] as String? ?? doc.id,
      systemKey: data['systemKey'] as String?,
      name: data['name'] as String? ?? 'Danh mục',
      type: data['type'] as String? ?? 'expense',
      iconKey: data['iconKey'] as String? ?? 'category',
      colorValue: (data['colorValue'] as num?)?.toInt(),
      isDefault: data['isDefault'] as bool? ?? false,
      isArchived: data['isArchived'] as bool? ?? false,
      sortOrder: (data['sortOrder'] as num?)?.toInt() ?? 0,
      createdAt: _dateFrom(data['createdAt']),
      updatedAt: _dateFrom(data['updatedAt']),
    );
  }
}

DateTime _dateFrom(Object? value) {
  if (value is Timestamp) return value.toDate();
  return DateTime.fromMillisecondsSinceEpoch(0);
}
