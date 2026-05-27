class DailyClosingBalanceModel {
  final String id;
  final String date; // "YYYY-MM-DD"
  final double closingCash;
  final double closingOnline;
  final double closingGold;
  final double closingDiamond;
  final DateTime createdAt;
  final DateTime updatedAt;

  DailyClosingBalanceModel({
    required this.id,
    required this.date,
    required this.closingCash,
    required this.closingOnline,
    required this.closingGold,
    required this.closingDiamond,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DailyClosingBalanceModel.fromMap(Map<String, dynamic> map) {
    return DailyClosingBalanceModel(
      id: map['_id'] ?? '',
      date: map['date'] ?? '',
      closingCash: (map['closingCash'] as num?)?.toDouble() ?? 0.0,
      closingOnline: (map['closingOnline'] as num?)?.toDouble() ?? 0.0,
      closingGold: (map['closingGold'] as num?)?.toDouble() ?? 0.0,
      closingDiamond: (map['closingDiamond'] as num?)?.toDouble() ?? 0.0,
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : DateTime.now(),
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      '_id': id,
      'date': date,
      'closingCash': closingCash,
      'closingOnline': closingOnline,
      'closingGold': closingGold,
      'closingDiamond': closingDiamond,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
