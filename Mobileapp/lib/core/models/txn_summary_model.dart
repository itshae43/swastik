import 'package:swastik_mobile_app/core/models/transaction_model.dart';

/// Running totals shown on the home summary cards.
///
/// These are the same four numbers the home dashboard displays (Total Cash /
/// Online / Gold / Diamond). They are produced server-side by the
/// `/transactions/summary` aggregation, but the shape and sign convention are
/// kept identical to the client's per-transaction formula so an optimistic
/// [deltaOf] computed on the device lines up exactly with the value the server
/// returns on the next poll.
class TxnSummary {
  final double cash;
  final double online;
  final double gold;
  final double diamond;

  const TxnSummary({
    this.cash = 0,
    this.online = 0,
    this.gold = 0,
    this.diamond = 0,
  });

  static const TxnSummary zero = TxnSummary();

  factory TxnSummary.fromMap(Map<String, dynamic> map) {
    return TxnSummary(
      cash: (map['cash'] as num?)?.toDouble() ?? 0,
      online: (map['online'] as num?)?.toDouble() ?? 0,
      gold: (map['gold'] as num?)?.toDouble() ?? 0,
      diamond: (map['diamond'] as num?)?.toDouble() ?? 0,
    );
  }

  TxnSummary operator +(TxnSummary o) => TxnSummary(
        cash: cash + o.cash,
        online: online + o.online,
        gold: gold + o.gold,
        diamond: diamond + o.diamond,
      );

  TxnSummary operator -(TxnSummary o) => TxnSummary(
        cash: cash - o.cash,
        online: online - o.online,
        gold: gold - o.gold,
        diamond: diamond - o.diamond,
      );

  /// The signed contribution a single transaction makes to the running totals —
  /// the client-side mirror of the server aggregation. Add it for an optimistic
  /// create, subtract it for a delete, and combine both for an edit.
  ///
  ///   • cash    → non-metal txns paid in cash
  ///   • online  → non-metal txns paid online / upi / rtgs
  ///   • gold    → metalType == 'gold'    (weight)
  ///   • diamond → metalType == 'diamond' (weight)
  /// Credits (receipt / metalIn) add, debits (payment / metalOut) subtract.
  static TxnSummary deltaOf(TransactionModel t) {
    final int sign;
    if (t.type == TransactionType.receipt || t.type == TransactionType.metalIn) {
      sign = 1;
    } else if (t.type == TransactionType.payment ||
        t.type == TransactionType.metalOut) {
      sign = -1;
    } else {
      sign = 0;
    }
    if (sign == 0) return zero;

    if (t.metalType.isEmpty) {
      final v = sign * t.cashAmount;
      final isCash = t.paymentMode == PaymentMode.cash;
      final isOnline = t.paymentMode == PaymentMode.online ||
          t.paymentMode == PaymentMode.upi ||
          t.paymentMode == PaymentMode.rtgs;
      return TxnSummary(cash: isCash ? v : 0, online: isOnline ? v : 0);
    }
    if (t.metalType == 'gold') return TxnSummary(gold: sign * t.metalWeight);
    if (t.metalType == 'diamond') return TxnSummary(diamond: sign * t.metalWeight);
    return zero;
  }
}
