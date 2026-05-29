import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swastik_mobile_app/core/models/transaction_model.dart';
import 'package:swastik_mobile_app/core/services/transaction_service.dart';
import 'package:swastik_mobile_app/core/utils/constants.dart';
import 'package:swastik_mobile_app/core/utils/time_utils.dart';

import 'package:swastik_mobile_app/core/models/daily_closing_balance_model.dart';
import 'package:swastik_mobile_app/features/auth/providers/auth_providers.dart';

final transactionServiceProvider = Provider<TransactionService>((ref) => TransactionService(ref));

final transactionsStreamProvider = StreamProvider<List<TransactionModel>>((ref) {
  return ref.watch(transactionServiceProvider).transactionsStream(AppConstants.centralDbId);
});

final partyTransactionsStreamProvider = StreamProvider.family<List<TransactionModel>, String>((ref, partyId) {
  return ref.watch(transactionServiceProvider).partyTransactionsStream(AppConstants.centralDbId, partyId);
});

final dailyBalancesStreamProvider = StreamProvider<List<DailyClosingBalanceModel>>((ref) {
  return ref.watch(transactionServiceProvider).dailyBalancesStream();
});


class TransactionState {
  final bool isLoading;
  final String? error;
  final bool isSuccess;

  const TransactionState({
    this.isLoading = false,
    this.error,
    this.isSuccess = false,
  });

  TransactionState copyWith({
    bool? isLoading,
    String? error,
    bool? isSuccess,
    bool clearError = false,
  }) {
    return TransactionState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

class TransactionNotifier extends Notifier<TransactionState> {
  @override
  TransactionState build() => const TransactionState();

  TransactionService get _transactionService => ref.read(transactionServiceProvider);

  Future<bool> createTransaction({
    required String partyId,
    required String partyName,
    required String partyPhone,
    required TransactionType type,
    required PaymentMode paymentMode,
    required double cashAmount,
    required String metalType,
    required double metalWeight,
    required String metalPurity,
    required String notes,
    required DateTime date,
  }) async {


    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final now = TimeUtils.now;
      final transaction = TransactionModel(
        id: '', 
        partyId: partyId,
        partyName: partyName,
        partyPhone: partyPhone,
        type: type,
        paymentMode: paymentMode,
        cashAmount: cashAmount,
        metalType: metalType,
        metalWeight: metalWeight,
        metalPurity: metalPurity,
        notes: notes,
        date: date,
        createdAt: now,
        createdBy: ref.read(currentUserProfileProvider)?.name ?? 'Admin',
      );

      await _transactionService.createTransaction(transaction);
      state = state.copyWith(isLoading: false, isSuccess: true);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> updateTransaction({
    required TransactionModel oldTx,
    required TransactionModel newTx,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final updatedTx = newTx;
      final finalTx = TransactionModel(
        id: updatedTx.id,
        partyId: updatedTx.partyId,
        partyName: updatedTx.partyName,
        partyPhone: updatedTx.partyPhone,
        type: updatedTx.type,
        paymentMode: updatedTx.paymentMode,
        cashAmount: updatedTx.cashAmount,
        metalType: updatedTx.metalType,
        metalWeight: updatedTx.metalWeight,
        metalPurity: updatedTx.metalPurity,
        notes: updatedTx.notes,
        date: updatedTx.date,
        createdAt: updatedTx.createdAt,
        createdBy: updatedTx.createdBy,
        updatedBy: ref.read(currentUserProfileProvider)?.name ?? 'Admin',
        updatedAt: TimeUtils.now,
      );

      await _transactionService.updateTransaction(oldTx, finalTx);
      state = state.copyWith(isLoading: false, isSuccess: true);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> deleteTransaction(TransactionModel transaction) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _transactionService.deleteTransaction(transaction);
      state = state.copyWith(isLoading: false, isSuccess: true);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}

final transactionNotifierProvider = NotifierProvider<TransactionNotifier, TransactionState>(TransactionNotifier.new);
