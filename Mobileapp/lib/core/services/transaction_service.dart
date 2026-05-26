import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transaction_model.dart';
import '../models/party_model.dart';
import '../utils/time_utils.dart';
import 'package:swastik_mobile_app/core/utils/device_identity.dart';
import 'package:swastik_mobile_app/features/auth/providers/auth_providers.dart';
import 'package:swastik_mobile_app/core/utils/constants.dart';

class TransactionService {
  final Ref? _ref;
  TransactionService([this._ref]);

  final String baseUrl = AppConstants.baseUrl;

  Map<String, String> _getHeaders() {
    final headers = {
      'Content-Type': 'application/json',
      'x-android-id': DeviceIdentity.androidId,
      'x-device-brand': DeviceIdentity.brand,
      'x-device-model': DeviceIdentity.model,
    };
    if (_ref != null) {
      final staffProfile = _ref.read(currentUserProfileProvider);
      if (staffProfile != null) {
        headers['x-staff-id'] = staffProfile.id;
      }
    }
    return headers;
  }

  Future<void> createTransaction(TransactionModel transaction) async {
    // 1. Fetch Party and update balance
    try {
      final allPartiesRes = await http.get(
        Uri.parse('$baseUrl/parties'),
        headers: _getHeaders(),
      );
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
            headers: _getHeaders(),
            body: jsonEncode(updatedParty.toMap()),
          );
        }
      }
    } catch (e) {
      // Log party balance adjustment failure but proceed to try creating transaction
    }

    // 2. Create Transaction
    await http.post(
      Uri.parse('$baseUrl/transactions'),
      headers: _getHeaders(),
      body: jsonEncode(transaction.toMap()),
    );
  }

  Future<void> deleteTransaction(TransactionModel transaction) async {
    // 1. Fetch Party and reverse balance impact
    try {
      final allPartiesRes = await http.get(
        Uri.parse('$baseUrl/parties'),
        headers: _getHeaders(),
      );
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

          // Reversing the transaction impact:
          // Subtract debits, add credits
          if (transaction.metalType.isEmpty) {
            if (isDebit) cashBalance -= transaction.cashAmount;
            if (isCredit) cashBalance += transaction.cashAmount;
          } else if (transaction.metalType == 'gold') {
            if (isDebit) goldBalance -= transaction.metalWeight;
            if (isCredit) goldBalance += transaction.metalWeight;
          } else if (transaction.metalType == 'diamond') {
            if (isDebit) diamondBalance -= transaction.metalWeight;
            if (isCredit) diamondBalance += transaction.metalWeight;
          }

          final updatedParty = party.copyWith(
            cashBalance: cashBalance,
            goldBalanceGrams: goldBalance,
            diamondBalanceCarats: diamondBalance,
            updatedAt: TimeUtils.now,
          );

          await http.put(
            Uri.parse('$baseUrl/parties/${party.id}'),
            headers: _getHeaders(),
            body: jsonEncode(updatedParty.toMap()),
          );
        }
      }
    } catch (e) {
      // Proceed even if balance adjustment fails
    }

    // 2. Delete Transaction
    await http.delete(
      Uri.parse('$baseUrl/transactions/${transaction.id}'),
      headers: _getHeaders(),
    );
  }

  Future<void> updateTransaction(TransactionModel oldTx, TransactionModel newTx) async {
    // 1. Fetch Party and update balance differences
    try {
      final allPartiesRes = await http.get(
        Uri.parse('$baseUrl/parties'),
        headers: _getHeaders(),
      );
      if (allPartiesRes.statusCode == 200) {
        final List allParties = jsonDecode(allPartiesRes.body);
        final partyMap = allParties.firstWhere((p) => p['_id'] == oldTx.partyId, orElse: () => null);
        if (partyMap != null) {
          final party = PartyModel.fromMap(partyMap['_id'], partyMap);

          double cashBalance = party.cashBalance;
          double goldBalance = party.goldBalanceGrams;
          double diamondBalance = party.diamondBalanceCarats;

          // A. Reverse old transaction impact: Subtract debits, add credits
          final wasDebit = oldTx.type == TransactionType.payment ||
              oldTx.type == TransactionType.sale ||
              oldTx.type == TransactionType.metalOut;

          final wasCredit = oldTx.type == TransactionType.receipt ||
              oldTx.type == TransactionType.purchase ||
              oldTx.type == TransactionType.metalIn ||
              oldTx.type == TransactionType.return_;

          if (oldTx.metalType.isEmpty) {
            if (wasDebit) cashBalance -= oldTx.cashAmount;
            if (wasCredit) cashBalance += oldTx.cashAmount;
          } else if (oldTx.metalType == 'gold') {
            if (wasDebit) goldBalance -= oldTx.metalWeight;
            if (wasCredit) goldBalance += oldTx.metalWeight;
          } else if (oldTx.metalType == 'diamond') {
            if (wasDebit) diamondBalance -= oldTx.metalWeight;
            if (wasCredit) diamondBalance += oldTx.metalWeight;
          }

          // B. Apply new transaction impact: Add debits, subtract credits
          final isDebit = newTx.type == TransactionType.payment ||
              newTx.type == TransactionType.sale ||
              newTx.type == TransactionType.metalOut;

          final isCredit = newTx.type == TransactionType.receipt ||
              newTx.type == TransactionType.purchase ||
              newTx.type == TransactionType.metalIn ||
              newTx.type == TransactionType.return_;

          if (newTx.metalType.isEmpty) {
            if (isDebit) cashBalance += newTx.cashAmount;
            if (isCredit) cashBalance -= newTx.cashAmount;
          } else if (newTx.metalType == 'gold') {
            if (isDebit) goldBalance += newTx.metalWeight;
            if (isCredit) goldBalance -= newTx.metalWeight;
          } else if (newTx.metalType == 'diamond') {
            if (isDebit) diamondBalance += newTx.metalWeight;
            if (isCredit) diamondBalance -= newTx.metalWeight;
          }

          final updatedParty = party.copyWith(
            cashBalance: cashBalance,
            goldBalanceGrams: goldBalance,
            diamondBalanceCarats: diamondBalance,
            updatedAt: TimeUtils.now,
          );

          await http.put(
            Uri.parse('$baseUrl/parties/${party.id}'),
            headers: _getHeaders(),
            body: jsonEncode(updatedParty.toMap()),
          );
        }
      }
    } catch (e) {
      // Proceed even if balance adjustment fails
    }

    // 2. Update Transaction
    await http.put(
      Uri.parse('$baseUrl/transactions/${newTx.id}'),
      headers: _getHeaders(),
      body: jsonEncode(newTx.toMap()),
    );
  }

  Stream<List<TransactionModel>> transactionsStream(String userId) async* {
    while (true) {
      try {
        final res = await http.get(
          Uri.parse('$baseUrl/transactions'),
          headers: _getHeaders(),
        );
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
        final res = await http.get(
          Uri.parse('$baseUrl/transactions'),
          headers: _getHeaders(),
        );
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
