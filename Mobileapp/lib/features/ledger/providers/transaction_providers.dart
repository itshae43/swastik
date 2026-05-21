import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swastik_mobile_app/core/models/transaction_model.dart';
import 'package:swastik_mobile_app/core/services/transaction_service.dart';
import 'package:swastik_mobile_app/features/auth/providers/auth_providers.dart';
import 'package:swastik_mobile_app/core/utils/constants.dart';

final transactionServiceProvider = Provider<TransactionService>((ref) => TransactionService());

final transactionsStreamProvider = StreamProvider<List<TransactionModel>>((ref) {
  return ref.watch(transactionServiceProvider).transactionsStream(AppConstants.centralDbId);
});

final partyTransactionsStreamProvider = StreamProvider.family<List<TransactionModel>, String>((ref, partyId) {
  return ref.watch(transactionServiceProvider).partyTransactionsStream(AppConstants.centralDbId, partyId);
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
      final now = DateTime.now();
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
      );

      await _transactionService.createTransaction(transaction);
      state = state.copyWith(isLoading: false, isSuccess: true);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}

final transactionNotifierProvider = NotifierProvider<TransactionNotifier, TransactionState>(TransactionNotifier.new);
