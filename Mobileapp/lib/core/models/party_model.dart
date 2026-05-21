class PartyModel {
  final String id;
  final String name;
  final String type; // 'Retail Customer', 'B2B Supplier', 'Karigar', 'Other'
  final String phone;
  final String email;
  final String address;
  final double cashBalance; // positive = they owe, negative = you owe
  final double goldBalanceGrams; // positive = they owe, negative = you owe
  final double silverBalanceGrams;
  final double diamondBalanceCarats;
  final double openingCashBalance;
  final double openingGoldBalanceGrams;
  final double openingDiamondBalanceCarats;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PartyModel({
    required this.id,
    required this.name,
    required this.type,
    required this.phone,
    required this.email,
    required this.address,
    required this.cashBalance,
    required this.goldBalanceGrams,
    required this.silverBalanceGrams,
    required this.diamondBalanceCarats,
    required this.openingCashBalance,
    required this.openingGoldBalanceGrams,
    required this.openingDiamondBalanceCarats,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PartyModel.fromMap(String id, Map<String, dynamic> map) {
    final cash = (map['cashBalance'] as num?)?.toDouble() ?? 0.0;
    final gold = (map['goldBalanceGrams'] as num?)?.toDouble() ?? 0.0;
    final diamond = (map['diamondBalanceCarats'] as num?)?.toDouble() ?? 0.0;
    
    return PartyModel(
      id: id,
      name: map['name'] as String? ?? '',
      type: map['type'] as String? ?? 'Other',
      phone: map['phone'] as String? ?? '',
      email: map['email'] as String? ?? '',
      address: map['address'] as String? ?? '',
      cashBalance: cash,
      goldBalanceGrams: gold,
      silverBalanceGrams: (map['silverBalanceGrams'] as num?)?.toDouble() ?? 0.0,
      diamondBalanceCarats: diamond,
      openingCashBalance: (map['openingCashBalance'] as num?)?.toDouble() ?? cash,
      openingGoldBalanceGrams: (map['openingGoldBalanceGrams'] as num?)?.toDouble() ?? gold,
      openingDiamondBalanceCarats: (map['openingDiamondBalanceCarats'] as num?)?.toDouble() ?? diamond,
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : DateTime.now(),
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type,
      'phone': phone,
      'email': email,
      'address': address,
      'cashBalance': cashBalance,
      'goldBalanceGrams': goldBalanceGrams,
      'silverBalanceGrams': silverBalanceGrams,
      'diamondBalanceCarats': diamondBalanceCarats,
      'openingCashBalance': openingCashBalance,
      'openingGoldBalanceGrams': openingGoldBalanceGrams,
      'openingDiamondBalanceCarats': openingDiamondBalanceCarats,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Dr = positive balance (they owe you)
  /// Cr = negative balance (you owe them)
  
  String get cashBalanceLabel {
    if (cashBalance > 0) return 'Dr (To Receive)';
    if (cashBalance < 0) return 'Cr (To Pay)';
    return 'Settled';
  }

  String get goldBalanceLabel {
    if (goldBalanceGrams > 0) return 'Dr (To Receive)';
    if (goldBalanceGrams < 0) return 'Cr (To Give)';
    return 'Settled';
  }

  String get diamondBalanceLabel {
    if (diamondBalanceCarats > 0) return 'Dr (To Receive)';
    if (diamondBalanceCarats < 0) return 'Cr (To Give)';
    return 'Settled';
  }

  PartyModel copyWith({
    String? id,
    String? name,
    String? type,
    String? phone,
    String? email,
    String? address,
    double? cashBalance,
    double? goldBalanceGrams,
    double? silverBalanceGrams,
    double? diamondBalanceCarats,
    double? openingCashBalance,
    double? openingGoldBalanceGrams,
    double? openingDiamondBalanceCarats,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PartyModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      cashBalance: cashBalance ?? this.cashBalance,
      goldBalanceGrams: goldBalanceGrams ?? this.goldBalanceGrams,
      silverBalanceGrams: silverBalanceGrams ?? this.silverBalanceGrams,
      diamondBalanceCarats: diamondBalanceCarats ?? this.diamondBalanceCarats,
      openingCashBalance: openingCashBalance ?? this.openingCashBalance,
      openingGoldBalanceGrams: openingGoldBalanceGrams ?? this.openingGoldBalanceGrams,
      openingDiamondBalanceCarats: openingDiamondBalanceCarats ?? this.openingDiamondBalanceCarats,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
