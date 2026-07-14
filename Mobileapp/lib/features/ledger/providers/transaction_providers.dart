import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swastik_mobile_app/core/models/transaction_model.dart';
import 'package:swastik_mobile_app/core/services/transaction_service.dart';
import 'package:swastik_mobile_app/core/utils/constants.dart';
import 'package:swastik_mobile_app/core/utils/time_utils.dart';

import 'package:swastik_mobile_app/core/models/daily_closing_balance_model.dart';
import 'package:swastik_mobile_app/features/auth/providers/auth_providers.dart';
import 'package:swastik_mobile_app/features/parties/providers/party_providers.dart';

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

/// Just the latest closing-balance row (current running totals) for the home
/// summary cards — avoids downloading the full day-by-day history.
final latestDailyBalanceProvider = StreamProvider<DailyClosingBalanceModel?>((ref) {
  return ref.watch(transactionServiceProvider).latestDailyBalanceStream();
});

// ─────────────────────────────────────────────────────────────────────────
// Home transactions table — server-side filtered + batched loading.
//
// Instead of downloading the entire transactions collection every poll and
// filtering on the device, the home table asks the server for exactly the
// window it needs:
//   • a date filter (Today / Week / Month / Custom) → bounded `from`/`to` fetch
//   • the "All" filter → batches of [pageSize], with `loadMore()` for the next
// This is what collapses the startup payload from "whole history" to one batch.
// ─────────────────────────────────────────────────────────────────────────

/// Describes what the home table should request from the server.
/// A date range (padded by the caller; the UI trims the exact days) or, when
/// [all] is true, the full collection loaded in batches.
class HomeTxnQuery {
  final DateTime? from;
  final DateTime? to;
  final bool all;

  const HomeTxnQuery({this.from, this.to, this.all = false});

  @override
  bool operator ==(Object other) =>
      other is HomeTxnQuery &&
      other.from == from &&
      other.to == to &&
      other.all == all;

  @override
  int get hashCode => Object.hash(from, to, all);
}

/// The current window the home table is showing, plus paging flags.
class HomeTxnState {
  final List<TransactionModel> items;
  final bool isLoading; // first load for the current query
  final bool isLoadingMore; // a loadMore() batch is in flight
  final bool hasMore; // another "All" batch is available
  final Object? error;

  const HomeTxnState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.error,
  });

  HomeTxnState copyWith({
    List<TransactionModel>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    Object? error,
    bool clearError = false,
  }) {
    return HomeTxnState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class HomeTransactionsNotifier extends Notifier<HomeTxnState> {
  static const int pageSize = 15;

  int _skip = 0;
  Timer? _timer;
  // Null until the UI pushes the first filter (via [setQuery]); the notifier
  // stays in its loading state and fetches nothing until then, so we never
  // accidentally download the whole collection before the filter is known.
  HomeTxnQuery? _query;

  @override
  HomeTxnState build() {
    ref.onDispose(() => _timer?.cancel());
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => _refreshInPlace(),
    );
    return const HomeTxnState(isLoading: true);
  }

  TransactionService get _svc => ref.read(transactionServiceProvider);

  /// Called by the UI whenever the selected filter changes. Refetches the first
  /// window for the new query; a no-op when the query is unchanged.
  Future<void> setQuery(HomeTxnQuery query) async {
    if (query == _query) return;
    _query = query;
    _skip = 0;
    await _reload();
  }

  Future<List<TransactionModel>> _fetch({required int skip}) {
    final q = _query!;
    return _svc.fetchTransactions(
      from: q.all ? null : q.from,
      to: q.all ? null : q.to,
      limit: q.all ? pageSize : null,
      skip: q.all ? skip : null,
    );
  }

  Future<void> _reload() async {
    if (_query == null) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final list = await _fetch(skip: 0);
      _skip = list.length;
      state = HomeTxnState(
        items: list,
        isLoading: false,
        hasMore: _query!.all && list.length >= pageSize,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  /// Loads the next batch (only meaningful for the "All" filter).
  Future<void> loadMore() async {
    final q = _query;
    if (q == null || !q.all || state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final more = await _fetch(skip: _skip);
      final combined = [...state.items, ...more];
      _skip = combined.length;
      state = state.copyWith(
        items: combined,
        isLoadingMore: false,
        hasMore: more.length >= pageSize,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  /// Pull-to-refresh: reload the current window from scratch.
  Future<void> refresh() => _reload();

  /// Silent poll refresh — re-fetch the currently visible window (including all
  /// already-loaded "All" batches) without disturbing scroll or paging.
  Future<void> _refreshInPlace() async {
    final q = _query;
    if (q == null) return;
    try {
      final list = await _svc.fetchTransactions(
        from: q.all ? null : q.from,
        to: q.all ? null : q.to,
        limit: q.all ? (_skip == 0 ? pageSize : _skip) : null,
        skip: q.all ? 0 : null,
      );
      if (q.all) _skip = list.length;
      state = state.copyWith(items: list, isLoading: false, clearError: true);
    } catch (_) {
      // Keep showing the last good window; the next tick retries.
    }
  }
}

final homeTransactionsProvider =
    NotifierProvider<HomeTransactionsNotifier, HomeTxnState>(
  HomeTransactionsNotifier.new,
);


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

  /// Forces the dashboard streams to refetch immediately after a mutation so
  /// the Home/Ledger screens reflect the change without waiting for the next
  /// (up to 12s) poll cycle. Home reads `asyncValue.value`, which Riverpod
  /// preserves across the invalidate, so the list updates in place with no
  /// loading flicker.
  void _refreshDashboardStreams() {
    ref.invalidate(transactionsStreamProvider);
    ref.invalidate(dailyBalancesStreamProvider);
    ref.invalidate(latestDailyBalanceProvider);
    ref.invalidate(partiesStreamProvider);
    // Home's table uses the server-side paginated provider — refresh its current
    // window in place (invalidating would drop the active filter/paging state).
    ref.read(homeTransactionsProvider.notifier).refresh();
  }

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
      _refreshDashboardStreams();
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
      _refreshDashboardStreams();
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
      _refreshDashboardStreams();
      state = state.copyWith(isLoading: false, isSuccess: true);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}

final transactionNotifierProvider = NotifierProvider<TransactionNotifier, TransactionState>(TransactionNotifier.new);
