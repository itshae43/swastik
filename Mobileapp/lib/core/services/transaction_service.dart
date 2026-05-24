import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/transaction_model.dart';
import '../models/party_model.dart';
import '../utils/time_utils.dart';

import 'package:swastik_mobile_app/core/utils/constants.dart';

class TransactionService {
  final String baseUrl = AppConstants.baseUrl;

  Future<void> createTransaction(TransactionModel transaction) async {
    // 1. Fetch Party
    final partyRes = await http.get(Uri.parse('$baseUrl/parties/${transaction.partyId}'));
    if (partyRes.statusCode == 200) {
      // For a single party we don't have a direct route in the basic setup, 
      // wait, the generic CRUD doesn't have GET /api/parties/:id unless we added it.
      // Let's just fetch all and find the one.
      final allPartiesRes = await http.get(Uri.parse('$baseUrl/parties'));
      if (allPartiesRes.statusCode == 200) {
        final List allParties = jsonDecode(allPartiesRes.body);
        final partyMap = allParties.firstWhere((p) => p['_id'] == transaction.partyId, orElse: () => null);
        if (partyMap != null) {
          final party = PartyModel.fromMap(partyMap['_id'], partyMap);

          double cashBalance = party.cashBalance;
          double goldBalance = party.goldBalanceGrams;
          double diamondBalance = party.diamondBalanceCarats;

          final isDebit = transaction.type == TransactionType.payment ||
              transaction.type == TransactionType.sale ||
              transaction.type == TransactionType.metalOut;

          final isCredit = transaction.type == TransactionType.receipt ||
              transaction.type == TransactionType.purchase ||
              transaction.type == TransactionType.metalIn ||
              transaction.type == TransactionType.return_;

          if (transaction.metalType.isEmpty) {
            if (isDebit) cashBalance += transaction.cashAmount;
            if (isCredit) cashBalance -= transaction.cashAmount;
          } else if (transaction.metalType == 'gold') {
            if (isDebit) goldBalance += transaction.metalWeight;
            if (isCredit) goldBalance -= transaction.metalWeight;
          } else if (transaction.metalType == 'diamond') {
            if (isDebit) diamondBalance += transaction.metalWeight;
            if (isCredit) diamondBalance -= transaction.metalWeight;
          }

          final updatedParty = party.copyWith(
            cashBalance: cashBalance,
            goldBalanceGrams: goldBalance,
            diamondBalanceCarats: diamondBalance,
            updatedAt: TimeUtils.now,
          );

          await http.put(
            Uri.parse('$baseUrl/parties/${party.id}'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(updatedParty.toMap()),
          );
        }
      }
    }

    // 2. Create Transaction
    await http.post(
      Uri.parse('$baseUrl/transactions'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(transaction.toMap()),
    );
  }

  Stream<List<TransactionModel>> transactionsStream(String userId) async* {
    while (true) {
      try {
        final res = await http.get(Uri.parse('$baseUrl/transactions'));
        if (res.statusCode == 200) {
          final List data = jsonDecode(res.body);
          final list = data.map((e) => TransactionModel.fromMap(e['_id'], e as Map<String, dynamic>)).toList();
          list.sort((a, b) => b.date.compareTo(a.date));
          yield list;
        }
      } catch (e) {}
      await Future.delayed(const Duration(seconds: 3));
    }
  }

  Stream<List<TransactionModel>> partyTransactionsStream(String userId, String partyId) async* {
    while (true) {
      try {
        final res = await http.get(Uri.parse('$baseUrl/transactions'));
        if (res.statusCode == 200) {
          final List data = jsonDecode(res.body);
          final list = data.map((e) => TransactionModel.fromMap(e['_id'], e as Map<String, dynamic>)).toList();
          final filtered = list.where((t) => t.partyId == partyId).toList();
          filtered.sort((a, b) => b.date.compareTo(a.date));
          yield filtered;
        }
      } catch (e) {}
      await Future.delayed(const Duration(seconds: 3));
    }
  }
}
