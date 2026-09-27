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
