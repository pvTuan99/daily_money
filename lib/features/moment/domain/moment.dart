class MomentSpending {
  const MomentSpending({
    required this.amount,
    required this.category,
    required this.wallet,
    this.note = '',
  });

  final int amount;
  final String category;
  final String wallet;
  final String note;

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'category': category,
        'wallet': wallet,
        'note': note,
      };

  factory MomentSpending.fromJson(Map<String, dynamic> json) {
    return MomentSpending(
      amount: json['amount'] as int? ?? 0,
      category: json['category'] as String? ?? '',
      wallet: json['wallet'] as String? ?? '',
      note: json['note'] as String? ?? '',
    );
  }
}

class Moment {
  const Moment({
    required this.id,
    required this.imagePath,
    required this.caption,
    required this.createdAt,
    this.spending,
  });

  final String id;
  final String imagePath;
  final String caption;
  final DateTime createdAt;
  final MomentSpending? spending;

  Map<String, dynamic> toJson() => {
        'id': id,
        'imagePath': imagePath,
        'caption': caption,
        'createdAt': createdAt.toIso8601String(),
        'spending': spending?.toJson(),
      };

  factory Moment.fromJson(Map<String, dynamic> json) {
    final spendingJson = json['spending'];

    return Moment(
      id: json['id'] as String? ?? '',
      imagePath: json['imagePath'] as String? ?? '',
      caption: json['caption'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      spending: spendingJson is Map<String, dynamic>
          ? MomentSpending.fromJson(spendingJson)
          : null,
    );
  }
}
