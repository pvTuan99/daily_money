import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/moment.dart';

class MomentCloudRepository {
  MomentCloudRepository._();

  static final MomentCloudRepository instance = MomentCloudRepository._();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>>? get _momentsCollection {
    final userId = _userId;
    if (userId == null) return null;

    return _firestore.collection('users').doc(userId).collection('moments');
  }

  Future<bool> upsertMoment(Moment moment) async {
    final collection = _momentsCollection;
    if (collection == null) return false;

    try {
      await collection.doc(moment.id).set(
        {
          'id': moment.id,
          'caption': moment.caption,
          'createdAt': Timestamp.fromDate(moment.createdAt),
          'spending': moment.spending?.toJson(),
          'hasImage': moment.imagePath.isNotEmpty,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      return true;
    } on FirebaseException {
      return false;
    }
  }

  Future<bool> deleteMoment(String momentId) async {
    final collection = _momentsCollection;
    if (collection == null) return false;

    try {
      await collection.doc(momentId).delete();
      return true;
    } on FirebaseException {
      return false;
    }
  }

  Future<int> syncMoments(Iterable<Moment> moments) async {
    var synced = 0;

    for (final moment in moments) {
      if (await upsertMoment(moment)) {
        synced++;
      }
    }

    return synced;
  }

  Future<List<Moment>> fetchMoments() async {
    final collection = _momentsCollection;
    if (collection == null) return const [];

    try {
      final snapshot = await collection
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        final createdAt = data['createdAt'];
        final spendingData = data['spending'];

        return Moment(
          id: data['id'] as String? ?? doc.id,
          imagePath: '',
          caption: data['caption'] as String? ?? '',
          createdAt: createdAt is Timestamp
              ? createdAt.toDate()
              : DateTime.fromMillisecondsSinceEpoch(0),
          spending: spendingData is Map<String, dynamic>
              ? MomentSpending.fromJson(spendingData)
              : spendingData is Map
                  ? MomentSpending.fromJson(
                      Map<String, dynamic>.from(spendingData),
                    )
                  : null,
        );
      }).toList();
    } on FirebaseException {
      return const [];
    }
  }

  Future<int?> cloudMomentCount() async {
    final collection = _momentsCollection;
    if (collection == null) return null;

    try {
      final snapshot = await collection.count().get();
      return snapshot.count ?? 0;
    } on FirebaseException {
      return null;
    }
  }
}
