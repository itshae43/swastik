import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swastik_mobile_app/core/models/user_model.dart';
import 'package:swastik_mobile_app/core/models/party_model.dart';
import 'package:swastik_mobile_app/core/models/transaction_model.dart';
import 'package:swastik_mobile_app/core/utils/responsive_utils.dart';
import 'package:swastik_mobile_app/features/auth/providers/auth_providers.dart';
import 'package:swastik_mobile_app/features/ledger/providers/transaction_providers.dart';
import 'package:swastik_mobile_app/features/navigation/presentation/providers/navigation_provider.dart';
import 'package:swastik_mobile_app/features/parties/providers/party_providers.dart';
import 'package:swastik_mobile_app/features/parties/presentation/widgets/quick_add_party_bottom_sheet.dart';
import 'package:intl/intl.dart';
import 'package:swastik_mobile_app/features/home/presentation/screens/statement_screen.dart';
import 'package:swastik_mobile_app/features/home/presentation/widgets/custom_filter_sheet.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // Search query state for Tablet Transaction Table
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _selectedTableFilter = 'All'; // Default is 'All'
  CustomFilterResult? _customFilterResult;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  PopupMenuItem<String> _buildFilterMenuItem(String value, String label, IconData icon) {
    final isSelected = _selectedTableFilter == value;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isSelected ? const Color(0xFF735C0F) : const Color(0xFF5E543F).withOpacity(0.7),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? const Color(0xFF735C0F) : Colors.black87,
            ),
          ),
          if (isSelected) ...[
            const Spacer(),
            const Icon(
              Icons.check_rounded,
              size: 16,
              color: Color(0xFF735C0F),
            ),
          ],
        ],
      ),
    );
  }

  /// Returns the display label for the current filter.
  String get _filterDisplayLabel {
    if (_selectedTableFilter == 'Custom' && _customFilterResult != null) {
      return _customFilterResult!.displayLabel;
    }
    return _selectedTableFilter;
  }

  /// Opens the premium custom filter bottom sheet.
  Future<void> _openCustomFilterSheet() async {
    final result = await showModalBottomSheet<CustomFilterResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CustomFilterSheet(initial: _customFilterResult),
    );
    if (result != null && mounted) {
      setState(() {
        _selectedTableFilter = 'Custom';
        _customFilterResult = result;
      });
    }
  }

  /// Applies date filtering to a list of transactions based on
  /// the current [_selectedTableFilter] and [_customFilterResult].
  List<TransactionModel> _applyDateFilter(List<TransactionModel> transactions) {
    final now = DateTime.now();
    return transactions.where((t) {
      if (_selectedTableFilter == 'Today') {
        return t.date.year == now.year &&
            t.date.month == now.month &&
            t.date.day == now.day;
      } else if (_selectedTableFilter == 'This Week') {
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final startOfToday = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        final txnDate = DateTime(t.date.year, t.date.month, t.date.day);
        return txnDate.isAfter(startOfToday.subtract(const Duration(days: 1))) &&
            txnDate.isBefore(DateTime(now.year, now.month, now.day).add(const Duration(days: 1)));
      } else if (_selectedTableFilter == 'This Month') {
        return t.date.year == now.year && t.date.month == now.month;
      } else if (_selectedTableFilter == 'Custom' && _customFilterResult != null) {
        final r = _customFilterResult!;
        switch (r.type) {
          case 'date':
            if (r.date != null) {
              return t.date.year == r.date!.year &&
                  t.date.month == r.date!.month &&
                  t.date.day == r.date!.day;
            }
            return true;
          case 'month_year':
            if (r.month != null && r.year != null) {
              return t.date.year == r.year && t.date.month == r.month;
            }
            return true;
          case 'month_only':
            if (r.month != null) {
              return t.date.month == r.month;
            }
            return true;
          default:
            return true;
        }
      }
      return true; // 'All'
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = AppResponsive.isTablet(context);
    final transactionsAsync = ref.watch(transactionsStreamProvider);
    final transactions = transactionsAsync.value ?? [];

    // Calculate balances dynamically
    double cashVal = 0.0;
    double onlineVal = 0.0;
    double goldVal = 0.0;
    double diamondVal = 0.0;

    for (final t in transactions) {
      final isCredit = t.type == TransactionType.receipt || t.type == TransactionType.metalIn;
      final isDebit = t.type == TransactionType.payment || t.type == TransactionType.metalOut;
      final val = t.metalType.isEmpty ? t.cashAmount : t.metalWeight;

      if (t.metalType.isEmpty) {
        if (t.paymentMode == PaymentMode.cash) {
          if (isCredit) cashVal += val;
          if (isDebit) cashVal -= val;
        } else if (t.paymentMode == PaymentMode.online ||
                   t.paymentMode == PaymentMode.upi ||
                   t.paymentMode == PaymentMode.rtgs) {
          if (isCredit) onlineVal += val;
          if (isDebit) onlineVal -= val;
        }
      } else if (t.metalType == 'gold') {
        if (isCredit) goldVal += val;
        if (isDebit) goldVal -= val;
      } else if (t.metalType == 'diamond') {
        if (isCredit) diamondVal += val;
        if (isDebit) diamondVal -= val;
      }
    }

    final String displayCash = '₹ ${NumberFormat.decimalPattern('en_IN').format(cashVal)}';
    final String displayOnline = '₹ ${NumberFormat.decimalPattern('en_IN').format(onlineVal)}';
    final String displayGold = '${goldVal % 1 == 0 ? goldVal.toInt().toString() : goldVal.toStringAsFixed(3).replaceAll(RegExp(r"\.?0+$"), "")} g';
    final String displayDiamond = '${diamondVal % 1 == 0 ? diamondVal.toInt().toString() : diamondVal.toStringAsFixed(2).replaceAll(RegExp(r"\.?0+$"), "")} ct';

    // Today's summary for Mobile
    double todayInVal = 0.0;
    double todayOutVal = 0.0;
    final now = DateTime.now();
    for (final t in transactions) {
      if (t.date.year == now.year && t.date.month == now.month && t.date.day == now.day) {
        if (t.metalType.isEmpty) {
          if (t.type == TransactionType.receipt) {
            todayInVal += t.cashAmount;
          } else if (t.type == TransactionType.payment) {
            todayOutVal += t.cashAmount;
          }
        }
      }
    }
    final String displayTodayIn = '+₹ ${NumberFormat.decimalPattern('en_IN').format(todayInVal)}';
    final String displayTodayOut = '-₹ ${NumberFormat.decimalPattern('en_IN').format(todayOutVal)}';

    if (isTablet) {
      return _buildTabletHomeScreen(
        transactionsAsync: transactionsAsync,
        cash: displayCash,
        online: displayOnline,
        gold: displayGold,
        diamond: displayDiamond,
      );
    }

    // Existing mobile layout
    return Container(
      color: const Color(0xFFFDFBF7),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileHeader(),
              const SizedBox(height: 24),
              _buildBalancesGrid(
                cash: displayCash,
                online: displayOnline,
                gold: displayGold,
                diamond: displayDiamond,
              ),
              const SizedBox(height: 24),
              _buildTodaysSummary(
                todayIn: displayTodayIn,
                todayOut: displayTodayOut,
              ),
              const SizedBox(height: 24),
              _buildRecentTransactions(),
              const SizedBox(height: 80), // Padding for bottom FAB
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TABLET SCREEN LAYOUT
  // ==========================================

  Widget _buildTabletHomeScreen({
    required AsyncValue<List<TransactionModel>> transactionsAsync,
    required String cash,
    required String online,
    required String gold,
    required String diamond,
  }) {
    final dateStr = DateFormat('EEEE, d MMMM').format(DateTime.now());
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;

    return GestureDetector(
      onTap: () {
        if (_searchFocusNode.hasFocus) {
          _searchFocusNode.unfocus();
        }
      },
      behavior: HitTestBehavior.translucent,
      child: Container(
        color: const Color(0xFFFAF6EE), // Beautiful warm beige/cream background
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section (Date and New Entry button)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    dateStr,
                    style: GoogleFonts.montserrat(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: const Color(
                        0xFF735C0F,
                      ), // Olive-gold text matching the screenshot
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        barrierDismissible: true,
                        builder: (context) => const Dialog(
                          backgroundColor: Colors.transparent,
                          child: TabletQuickAddEntryDialog(),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.add,
                      color: Color(0xFF01565B),
                      size: 18,
                    ),
                    label: Text(
                      'New Entry',
                      style: GoogleFonts.montserrat(
                        color: const Color(0xFF01565B),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(
                        0xFFDFBA6B,
                      ), // Gold background
                      elevation: 2,
                      shadowColor: Colors.black.withOpacity(0.1),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Summary Cards Grid (4 Cards Row)
              _buildTabletSummaryCards(
                cash: cash,
                online: online,
                gold: gold,
                diamond: diamond,
              ),
              const SizedBox(height: 28),

              // Recent Transactions Table inside a beautifully styled Card
              _buildTabletTransactionsTable(transactionsAsync),
            ],
          ),
        ),
      ),
     ),
    );
  }

  Widget _buildTabletSummaryCards({
    required String cash,
    required String online,
    required String gold,
    required String diamond,
  }) {
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    if (isPortrait) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildTabletCard(
                  label: 'TOTAL CASH',
                  value: cash,
                  accentColor: const Color(0xFF01565B),
                  icon: Icons.payments_outlined,
                  iconColor: const Color(0xFF01565B),
                  iconBgColor: const Color(0xFFE8F8F0),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TransactionStatementScreen(category: 'cash'),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTabletCard(
                  label: 'TOTAL UPI/RTGS',
                  value: online,
                  accentColor: const Color(0xFF2E5BFF),
                  icon: Icons.account_balance_rounded,
                  iconColor: const Color(0xFF2E5BFF),
                  iconBgColor: const Color(0xFFE6F0FA),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TransactionStatementScreen(category: 'online'),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTabletCard(
                  label: 'TOTAL GOLD',
                  value: gold,
                  accentColor: const Color(0xFFDFBA6B),
                  icon: Icons.widgets_rounded,
                  iconColor: const Color(0xFF735C0F),
                  iconBgColor: const Color(0xFFFFF9E6),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TransactionStatementScreen(category: 'gold'),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTabletCard(
                  label: 'TOTAL DIAMOND',
                  value: diamond,
                  accentColor: const Color(0xFF8EACCD),
                  icon: Icons.diamond_rounded,
                  iconColor: const Color(0xFF4F709C),
                  iconBgColor: const Color(0xFFE3EDF7),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TransactionStatementScreen(category: 'diamond'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _buildTabletCard(
            label: 'TOTAL CASH',
            value: cash,
            accentColor: const Color(0xFF01565B),
            icon: Icons.payments_outlined,
            iconColor: const Color(0xFF01565B),
            iconBgColor: const Color(0xFFE8F8F0),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const TransactionStatementScreen(category: 'cash'),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildTabletCard(
            label: 'TOTAL UPI/RTGS',
            value: online,
            accentColor: const Color(0xFF2E5BFF),
            icon: Icons.account_balance_rounded,
            iconColor: const Color(0xFF2E5BFF),
            iconBgColor: const Color(0xFFE6F0FA),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const TransactionStatementScreen(category: 'online'),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildTabletCard(
            label: 'TOTAL GOLD',
            value: gold,
            accentColor: const Color(0xFFDFBA6B),
            icon: Icons.widgets_rounded,
            iconColor: const Color(0xFF735C0F),
            iconBgColor: const Color(0xFFFFF9E6),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const TransactionStatementScreen(category: 'gold'),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildTabletCard(
            label: 'TOTAL DIAMOND',
            value: diamond,
            accentColor: const Color(0xFF8EACCD),
            icon: Icons.diamond_rounded,
            iconColor: const Color(0xFF4F709C),
            iconBgColor: const Color(0xFFE3EDF7),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const TransactionStatementScreen(category: 'diamond'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabletCard({
    required String label,
    required String value,
    required Color accentColor,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 104,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFE5DEC9).withOpacity(0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            // Left colored accent strip
            Container(width: 4, color: accentColor),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          label,
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            color: const Color(0xFF5E543F).withOpacity(0.8),
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: iconBgColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: iconColor, size: 16),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          value,
                          style: GoogleFonts.montserrat(
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF01565B).withOpacity(0.3),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0xFF01565B),
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabletTransactionsTable(
    AsyncValue<List<TransactionModel>> transactionsAsync,
  ) {
    final transactions = transactionsAsync.value ?? [];
    final now = DateTime.now();

    // 1. Date filter (uses shared _applyDateFilter)
    final dateFilteredTransactions = _applyDateFilter(transactions);

    // 2. Search query filter
    final filtered = dateFilteredTransactions.where((t) {
      final query = _searchQuery.toLowerCase().trim();
      if (query.isEmpty) return true;
      return t.partyName.toLowerCase().contains(query) ||
          (t.notes?.toLowerCase().contains(query) ?? false) ||
          t.metalType.toLowerCase().contains(query);
    }).toList();

    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    final bool isSearchActive = isPortrait && (_searchFocusNode.hasFocus || _searchQuery.isNotEmpty);
    final int dateFlex = 2;
    final int nameFlex = isPortrait ? 4 : 3;
    final int categoryFlex = 2;
    final int amountFlex = 2;
    final int notesFlex = isPortrait ? 3 : 3;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE5DEC9).withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table Title, Search Bar and Filter row
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (!isSearchActive) ...[
                  Text(
                    'Recent Transaction',
                    style: GoogleFonts.montserrat(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF01565B),
                    ),
                  ),
                  Row(
                    children: [
                      // Collapsible Search Field
                      GestureDetector(
                        onTap: () {
                          if (!_searchFocusNode.hasFocus) {
                            _searchFocusNode.requestFocus();
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOutCubic,
                          width: (!isPortrait || _searchFocusNode.hasFocus || _searchQuery.isNotEmpty) ? 240.0 : 40.0,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF6EE),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE5DEC9)),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            onChanged: (val) {
                              setState(() {
                                _searchQuery = val;
                              });
                            },
                            style: GoogleFonts.montserrat(fontSize: 13),
                            textAlignVertical: TextAlignVertical.center,
                            decoration: InputDecoration(
                              hintText: (!isPortrait || _searchFocusNode.hasFocus || _searchQuery.isNotEmpty) ? 'Search' : '',
                              hintStyle: GoogleFonts.montserrat(
                                color: const Color(0xFF5E543F).withOpacity(0.6),
                                fontSize: 13,
                              ),
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                size: 18,
                                color: Color(0xFF5E543F),
                              ),
                              suffixIcon: ((!isPortrait || _searchFocusNode.hasFocus) && _searchQuery.isNotEmpty)
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF5E543F)),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {
                                          _searchQuery = '';
                                        });
                                        if (isPortrait) {
                                          _searchFocusNode.unfocus();
                                        }
                                      },
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    )
                                  : null,
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Filter Button
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'Custom') {
                            _openCustomFilterSheet();
                          } else {
                            setState(() {
                              _selectedTableFilter = value;
                              _customFilterResult = null;
                            });
                          }
                        },
                        itemBuilder: (context) => [
                          _buildFilterMenuItem('All', 'All', Icons.all_inclusive_rounded),
                          _buildFilterMenuItem('Today', 'Today', Icons.today_rounded),
                          _buildFilterMenuItem('This Week', 'This Week', Icons.date_range_rounded),
                          _buildFilterMenuItem('This Month', 'This Month', Icons.calendar_month_rounded),
                          _buildFilterMenuItem('Custom', 'Custom', Icons.tune_rounded),
                        ],
                        child: Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF6EE),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE5DEC9)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.filter_list_rounded,
                                size: 18,
                                color: Color(0xFF5E543F),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Filter: $_filterDisplayLabel',
                                style: GoogleFonts.montserrat(
                                  color: const Color(0xFF5E543F),
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Print Button
                      GestureDetector(
                        onTap: () {
                          _showPrintStatementDialog(
                            context,
                            filtered,
                            'SwarnKhata Statement',
                            'Period: $_filterDisplayLabel',
                          );
                        },
                        child: Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF6EE),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE5DEC9)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.print_rounded,
                                size: 18,
                                color: Color(0xFF735C0F),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Print',
                                style: GoogleFonts.montserrat(
                                  color: const Color(0xFF735C0F),
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // Full-width search row with back button when search is active in portrait mode
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF01565B)),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                      _searchFocusNode.unfocus();
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF6EE),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE5DEC9)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                          });
                        },
                        style: GoogleFonts.montserrat(fontSize: 13),
                        textAlignVertical: TextAlignVertical.center,
                        decoration: InputDecoration(
                          hintText: 'Search by customer name, notes, or metal type',
                          hintStyle: GoogleFonts.montserrat(
                            color: const Color(0xFF5E543F).withOpacity(0.6),
                            fontSize: 13,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 18,
                            color: Color(0xFF5E543F),
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF5E543F)),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                    });
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                )
                              : null,
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            color: const Color(0xFFFAF6EE),
            child: Row(
              children: [
                Expanded(
                  flex: dateFlex,
                  child: Text(
                    'DATE',
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 16 / 12,
                      letterSpacing: 12 * 0.08,
                      color: const Color(0xFF5E543F),
                    ),
                  ),
                ),
                Expanded(
                  flex: nameFlex,
                  child: Text(
                    'CUSTOMER NAME',
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 16 / 12,
                      letterSpacing: 12 * 0.08,
                      color: const Color(0xFF5E543F),
                    ),
                  ),
                ),
                Expanded(
                  flex: categoryFlex,
                  child: Text(
                    'CATEGORY',
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 16 / 12,
                      letterSpacing: 12 * 0.08,
                      color: const Color(0xFF5E543F),
                    ),
                  ),
                ),
                Expanded(
                  flex: amountFlex,
                  child: Text(
                    'VALUE',
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 16 / 12,
                      letterSpacing: 12 * 0.08,
                      color: const Color(0xFF5E543F),
                    ),
                  ),
                ),
                Expanded(
                  flex: notesFlex,
                  child: Text(
                    'NOTES',
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 16 / 12,
                      letterSpacing: 12 * 0.08,
                      color: const Color(0xFF5E543F),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Transaction Rows & Dynamic Calculations
          transactionsAsync.when(
            data: (transactions) {
              // Using pre-filtered transactions list from outer scope of _buildTabletHomeScreen
              if (filtered.isEmpty) {
                return Container(
                  height: 160,
                  alignment: Alignment.center,
                  child: Text(
                    transactions.isEmpty
                        ? 'No transactions recorded'
                        : 'No matching transactions found',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      height: 20 / 14,
                      letterSpacing: 0,
                      color: const Color(0xFF5E543F).withOpacity(0.6),
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) => const Divider(
                      color: Color(0xFFE5DEC9),
                      height: 24,
                      thickness: 1.2,
                    ),
                    itemBuilder: (context, index) {
                      final t = filtered[index];
                      final isCredit =
                          t.type == TransactionType.receipt ||
                          t.type == TransactionType.metalIn;
                      final dateStr = DateFormat('dd MMM, yyyy').format(t.date);
                      final timeStr = DateFormat('hh:mm a').format(t.date);

                      // Customer Avatar color based on initials/name
                      final initial = t.partyName.isNotEmpty
                          ? t.partyName[0].toUpperCase()
                          : '?';
                      final avatarBgColor = _getAvatarColorForName(t.partyName);

                      // Category Pill using Transaction Type / Badge specs
                      Widget categoryPill;
                      if (t.metalType.isEmpty) {
                        categoryPill = _buildCategoryPill(
                          'Cash',
                          const Color(0xFFE8F8F0),
                          const Color(0xFF00994C),
                        );
                      } else if (t.metalType == 'gold') {
                        categoryPill = _buildCategoryPill(
                          'Gold',
                          const Color(0xFFFFF9E6),
                          const Color(0xFFB38600),
                        );
                      } else {
                        categoryPill = _buildCategoryPill(
                          'Diamond',
                          const Color(0xFFE6F0FA),
                          const Color(0xFF0066CC),
                        );
                      }

                      // Amount
                      String amountStr = '';
                      final amountColor = isCredit
                          ? const Color(0xFF01565B)
                          : const Color(0xFFC62828);
                      final sign = isCredit ? '+ ' : '- ';

                      if (t.metalType.isEmpty) {
                        amountStr =
                            '$sign₹ ${NumberFormat.decimalPattern('en_IN').format(t.cashAmount)}';
                      } else if (t.metalType == 'gold') {
                        amountStr = '$sign${t.metalWeight} g';
                      } else {
                        amountStr = '$sign${t.metalWeight} ct';
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ), // Adjusted vertical padding to pair with new divider height
                        child: Row(
                          children: [
                            // DATE Column (Styled with Timestamp Spec)
                            Expanded(
                              flex: dateFlex,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    dateStr,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      height: 16 / 12,
                                      letterSpacing: 12 * 0.01,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    timeStr,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                      height: 16 / 12,
                                      letterSpacing: 12 * 0.01,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // CUSTOMER NAME Column (Styled with Party Name Spec & Row Primary)
                            Expanded(
                              flex: nameFlex,
                              child: Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: avatarBgColor,
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      initial,
                                      style: GoogleFonts.montserrat(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        height: 20 / 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      t.partyName,
                                      style: GoogleFonts.montserrat(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        height: 22 / 16,
                                        letterSpacing: 0,
                                        color: Colors.black87,
                                      ),
                                      maxLines: isPortrait ? null : 1,
                                      overflow: isPortrait
                                          ? null
                                          : TextOverflow.ellipsis,
                                      softWrap: true,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // CATEGORY Column
                            Expanded(
                              flex: categoryFlex,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: categoryPill,
                              ),
                            ),

                            // VALUE Column (Styled with Credit/Debit Amount Specs)
                            Expanded(
                              flex: amountFlex,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    amountStr,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      height: 20 / 15,
                                      letterSpacing: 0,
                                      color: amountColor,
                                    ),
                                  ),
                                  if (t.metalType == 'gold' &&
                                      t.metalPurity.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFAF6EE),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: const Color(0xFFE5DEC9),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Text(
                                        t.metalPurity.endsWith('%') || t.metalPurity.contains('Purity')
                                            ? t.metalPurity
                                            : '${t.metalPurity}% Purity',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF735C0F),
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (t.metalType == 'diamond' &&
                                      t.metalPurity.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Builder(
                                      builder: (context) {
                                        String displayPieces = t.metalPurity;
                                        if (displayPieces.endsWith(' p')) {
                                          displayPieces = displayPieces
                                              .replaceAll(' p', ' Pcs');
                                        } else if (!displayPieces.contains(
                                              'Pcs',
                                            ) &&
                                            !displayPieces.contains(
                                              'pcs',
                                            ) &&
                                            !displayPieces.contains('p')) {
                                          displayPieces = '$displayPieces Pcs';
                                        } else if (displayPieces.contains('pcs')) {
                                          displayPieces = displayPieces.replaceAll('pcs', 'Pcs');
                                        }
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFAF6EE),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: const Color(0xFFE5DEC9),
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Text(
                                            displayPieces,
                                            style: GoogleFonts.montserrat(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF735C0F),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // NOTES Column (Styled with Secondary Details Spec)
                            Expanded(
                              flex: notesFlex,
                              child: Text(
                                t.notes != null && t.notes!.trim().isNotEmpty
                                    ? t.notes!
                                    : '-',
                                style: GoogleFonts.montserrat(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  height: 18 / 13,
                                  letterSpacing: 0,
                                  color: Colors.black54,
                                ),
                                maxLines: isPortrait ? null : 1,
                                overflow: isPortrait
                                    ? null
                                    : TextOverflow.ellipsis,
                                softWrap: true,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Error loading transactions'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPill(String label, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: GoogleFonts.montserrat(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          height: 18 / 13,
          letterSpacing: 13 * 0.02,
          color: textColor,
        ),
      ),
    );
  }

  Color _getAvatarColorForName(String name) {
    if (name.isEmpty) return const Color(0xFF01565B);
    final code = name.codeUnitAt(0);
    final colors = [
      const Color(0xFF2E5BFF),
      const Color(0xFF8EACCD),
      const Color(0xFF01565B),
      const Color(0xFFDFBA6B),
      const Color(0xFFCFA63A),
    ];
    return colors[code % colors.length];
  }

  // ==========================================
  // MOBILE SCREEN LAYOUT (UNCHANGED CORE ELEMENTS)
  // ==========================================

  Widget _buildProfileHeader() {
    final userName = 'Admin';
    final initial = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF8A7311), width: 1.5),
          ),
          child: CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFD4B13B),
            child: Text(
              initial,
              style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            userName,
            style: GoogleFonts.montserrat(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF6B5800),
              letterSpacing: -0.5,
            ),
          ),
        ),
        IconButton(
          onPressed: () {},
          icon: const Icon(
            Icons.notifications_none_outlined,
            color: Color(0xFF4A3E1F),
            size: 28,
          ),
        ),
      ],
    );
  }

  Widget _buildBalancesGrid({
    required String cash,
    required String online,
    required String gold,
    required String diamond,
  }) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        _buildGridCard(
          'Total Cash',
          cash,
          Icons.account_balance_wallet_outlined,
          const Color(0xFFF9F6ED),
          const Color(0xFFB08900),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const TransactionStatementScreen(category: 'cash'),
            ),
          ),
        ),
        _buildGridCard(
          'Online Balance',
          online,
          Icons.account_balance_outlined,
          const Color(0xFFF9F6ED),
          const Color(0xFFB08900),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const TransactionStatementScreen(category: 'online'),
            ),
          ),
        ),
        _buildGridCard(
          'Gold Balance',
          gold,
          Icons.widgets_outlined,
          const Color(0xFFE8C73D),
          const Color(0xFF4A3E1F),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const TransactionStatementScreen(category: 'gold'),
            ),
          ),
        ),
        _buildGridCard(
          'Diamond Balance',
          diamond,
          Icons.diamond_outlined,
          const Color(0xFFE3EDF7),
          const Color(0xFF5B81A8),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const TransactionStatementScreen(category: 'diamond'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGridCard(
    String title,
    String value,
    IconData icon,
    Color iconBgColor,
    Color iconColor, {
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodaysSummary({required String todayIn, required String todayOut}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Today's Summary",
          style: GoogleFonts.montserrat(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withOpacity(0.15)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 16,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFDFCF7),
                    borderRadius: BorderRadius.horizontal(
                      left: Radius.circular(16),
                    ),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFF8A7311),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.arrow_downward,
                                  size: 16,
                                  color: Color(0xFF757575),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  "IN",
                                  style: GoogleFonts.montserrat(
                                    fontSize: 13,
                                    color: const Color(0xFF757575),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              todayIn,
                              style: GoogleFonts.montserrat(
                                fontSize: 22,
                                color: const Color(0xFF8A7311),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 60,
                color: Colors.grey.withOpacity(0.15),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 16,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF9F9),
                    borderRadius: BorderRadius.horizontal(
                      right: Radius.circular(16),
                    ),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFC62828),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.arrow_upward,
                                  size: 16,
                                  color: Color(0xFF757575),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  "OUT",
                                  style: GoogleFonts.montserrat(
                                    fontSize: 13,
                                    color: const Color(0xFF757575),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              todayOut,
                              style: GoogleFonts.montserrat(
                                fontSize: 22,
                                color: const Color(0xFFC62828),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecentTransactions() {
    final transactionsAsync = ref.watch(transactionsStreamProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                "Recent Activity",
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF4A3E1F),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            // Filter Button (mobile)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'Custom') {
                  _openCustomFilterSheet();
                } else {
                  setState(() {
                    _selectedTableFilter = value;
                    _customFilterResult = null;
                  });
                }
              },
              itemBuilder: (context) => [
                _buildFilterMenuItem('All', 'All', Icons.all_inclusive_rounded),
                _buildFilterMenuItem('Today', 'Today', Icons.today_rounded),
                _buildFilterMenuItem('This Week', 'This Week', Icons.date_range_rounded),
                _buildFilterMenuItem('This Month', 'This Month', Icons.calendar_month_rounded),
                _buildFilterMenuItem('Custom', 'Custom', Icons.tune_rounded),
              ],
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF6EE),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE5DEC9)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.filter_list_rounded,
                      size: 14,
                      color: Color(0xFF5E543F),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _filterDisplayLabel,
                      style: GoogleFonts.montserrat(
                        color: const Color(0xFF5E543F),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                ref
                    .read(navigationProvider.notifier)
                    .setIndex(2); // Redirect to Ledger
              },
              child: Text(
                "View All",
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF8A7311),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        transactionsAsync.when(
          data: (transactions) {
            // Apply the shared date filter
            final filteredTransactions = _applyDateFilter(transactions);

            if (filteredTransactions.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.withOpacity(0.1)),
                ),
                child: Center(
                  child: Text(
                    'No transactions for this period',
                    style: GoogleFonts.montserrat(color: Colors.grey),
                  ),
                ),
              );
            }

            final recent = filteredTransactions.take(4).toList();

            return Column(
              children: recent.map((activity) {
                final isCredit =
                    activity.type == TransactionType.receipt ||
                    activity.type == TransactionType.metalIn;
                final color = isCredit
                    ? const Color(0xFF2852C6)
                    : const Color(0xFFC62828);
                final typeLabel = isCredit ? 'In' : 'Out';

                String topRightLabel = '';
                String middleRightLabel = '';

                if (activity.metalType.isEmpty) {
                  topRightLabel = activity.paymentMode.name.toUpperCase();
                  middleRightLabel =
                      '₹ ${NumberFormat.decimalPattern('en_IN').format(activity.cashAmount)}';
                } else if (activity.metalType == 'gold') {
                  topRightLabel = 'Gold (${activity.metalPurity.endsWith('%') ? activity.metalPurity : '${activity.metalPurity}%'})';
                  middleRightLabel = '${activity.metalWeight}g';
                } else if (activity.metalType == 'diamond') {
                  topRightLabel = 'Diamond (${activity.metalWeight}ct)';
                  String displayPieces = activity.metalPurity;
                  if (displayPieces.endsWith(' p')) {
                    displayPieces = displayPieces.replaceAll(' p', ' Pcs');
                  } else if (!displayPieces.contains('Pcs') &&
                      !displayPieces.contains('pcs') &&
                      !displayPieces.contains('p') &&
                      displayPieces.isNotEmpty) {
                    displayPieces = '$displayPieces Pcs';
                  } else if (displayPieces.contains('pcs')) {
                    displayPieces = displayPieces.replaceAll('pcs', 'Pcs');
                  }
                  middleRightLabel = displayPieces;
                }

                final initial = activity.partyName.isNotEmpty
                    ? activity.partyName[0].toUpperCase()
                    : '?';
                final dateStr = DateFormat('dd MMM yyyy').format(activity.date);
                final timeStr = DateFormat('hh:mm a').format(activity.date);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: 4,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              bottomLeft: Radius.circular(16),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF0EBE1),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    initial,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF6B5800),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        activity.partyName,
                                        style: GoogleFonts.montserrat(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        dateStr,
                                        style: GoogleFonts.montserrat(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        timeStr,
                                        style: GoogleFonts.montserrat(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      topRightLabel,
                                      style: GoogleFonts.montserrat(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: color,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      middleRightLabel,
                                      style: GoogleFonts.montserrat(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: color,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      typeLabel,
                                      style: GoogleFonts.montserrat(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: color,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error loading transactions')),
        ),
      ],
    );
  }

  void _showPrintStatementDialog(
    BuildContext context,
    List<TransactionModel> txns,
    String title,
    String subtitle,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        bool isPrinting = false;
        bool isSaved = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF6EE),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFDFBA6B), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 25,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: const BoxDecoration(
                        color: Color(0xFF01565B),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(18),
                          topRight: Radius.circular(18),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Print Statement Preview',
                            style: GoogleFonts.montserrat(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 20),
                            onPressed: () => Navigator.pop(context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),

                    if (isPrinting)
                      Container(
                        height: 350,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(color: Color(0xFF01565B)),
                            const SizedBox(height: 20),
                            Text(
                              'Preparing statement sheet...',
                              style: GoogleFonts.montserrat(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF5E543F),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Sending documents to printer spooler...',
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (isSaved)
                      Container(
                        height: 350,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(
                                color: Color(0xFFE8F8F0),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF01565B),
                                size: 48,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Statement Saved!',
                              style: GoogleFonts.montserrat(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF01565B),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'PDF saved to Documents/SwarnKhata/Statements',
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 24),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                'Dismiss',
                                style: GoogleFonts.montserrat(
                                  color: const Color(0xFF01565B),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      // Preview Content
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.withOpacity(0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Center(
                                  child: Column(
                                    children: [
                                      Text(
                                        'SWASTIK JEWELS',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF735C0F),
                                          letterSpacing: 2,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        subtitle,
                                        style: GoogleFonts.montserrat(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Divider(height: 1, color: Colors.grey[300]),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Total Entries:',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    Text(
                                      '${txns.length} items',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Table(
                                  border: TableBorder.all(color: Colors.grey.withOpacity(0.3), width: 0.5),
                                  columnWidths: const {
                                    0: FlexColumnWidth(2),
                                    1: FlexColumnWidth(3),
                                    2: FlexColumnWidth(2.5),
                                  },
                                  children: [
                                    TableRow(
                                      decoration: const BoxDecoration(color: Color(0xFFFAF6EE)),
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(4.0),
                                          child: Text('Date', style: GoogleFonts.montserrat(fontSize: 8, fontWeight: FontWeight.bold)),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(4.0),
                                          child: Text('Party / Mode', style: GoogleFonts.montserrat(fontSize: 8, fontWeight: FontWeight.bold)),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(4.0),
                                          child: Text('Value', style: GoogleFonts.montserrat(fontSize: 8, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                    ...txns.take(8).map((txn) {
                                      final isCr = txn.type == TransactionType.receipt || txn.type == TransactionType.metalIn;
                                      String categoryUnit = '';
                                      if (txn.metalType == 'gold') {
                                        categoryUnit = 'g';
                                      } else if (txn.metalType == 'diamond') {
                                        categoryUnit = 'ct';
                                      }

                                      final amt = txn.metalType.isEmpty 
                                          ? '₹${NumberFormat.decimalPattern('en_IN').format(txn.cashAmount)}'
                                          : '${txn.metalWeight} $categoryUnit';
                                      return TableRow(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.all(4.0),
                                            child: Text(DateFormat('dd MMM').format(txn.date), style: GoogleFonts.montserrat(fontSize: 8)),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(4.0),
                                            child: Text(
                                              txn.partyName,
                                              style: GoogleFonts.montserrat(fontSize: 8),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(4.0),
                                            child: Text(
                                              '${isCr ? '+' : '-'}$amt',
                                              style: GoogleFonts.montserrat(
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold,
                                                color: isCr ? const Color(0xFF01565B) : const Color(0xFFC62828),
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    }),
                                  ],
                                ),
                                if (txns.length > 8) ...[
                                  const SizedBox(height: 6),
                                  Center(
                                    child: Text(
                                      '... and ${txns.length - 8} more entries ...',
                                      style: GoogleFonts.montserrat(fontSize: 8, color: Colors.grey),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Print Dialog Actions
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  setDialogState(() {
                                    isPrinting = true;
                                  });
                                  Future.delayed(const Duration(seconds: 2), () {
                                    setDialogState(() {
                                      isPrinting = false;
                                      isSaved = true;
                                    });
                                  });
                                },
                                icon: const Icon(Icons.print_rounded, size: 18, color: Color(0xFF01565B)),
                                label: Text(
                                  'Print Statement',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF01565B),
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFF01565B), width: 1.5),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  setDialogState(() {
                                    isPrinting = true;
                                  });
                                  Future.delayed(const Duration(seconds: 1), () {
                                    setDialogState(() {
                                      isPrinting = false;
                                      isSaved = true;
                                    });
                                  });
                                },
                                icon: const Icon(Icons.picture_as_pdf, size: 18, color: Colors.white),
                                label: Text(
                                  'Save PDF',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF01565B),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ==========================================
// TABLET QUICK ADD DIALOG & FORMATTERS
// ==========================================

class TabletQuickAddEntryDialog extends ConsumerStatefulWidget {
  const TabletQuickAddEntryDialog({super.key});

  @override
  ConsumerState<TabletQuickAddEntryDialog> createState() =>
      _TabletQuickAddEntryDialogState();
}

class _TabletQuickAddEntryDialogState
    extends ConsumerState<TabletQuickAddEntryDialog> {
  String _transactionType = 'IN';
  String _category = 'Money'; // Money, Gold, Diamond
  String _paymentMode = 'Cash'; // Cash, UPI, RTGS
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _partyController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _purityController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _caratController = TextEditingController();
  final TextEditingController _piecesController = TextEditingController();
  final FocusNode _partyFocusNode = FocusNode();

  PartyModel? _selectedParty;
  String? _pendingPartyId;
  bool _isSaving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _partyController.dispose();
    _notesController.dispose();
    _purityController.dispose();
    _weightController.dispose();
    _caratController.dispose();
    _piecesController.dispose();
    _partyFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parties = ref.watch(partiesStreamProvider).value ?? [];

    if (_pendingPartyId != null && parties.isNotEmpty) {
      try {
        final party = parties.firstWhere((p) => p.id == _pendingPartyId);
        _pendingPartyId = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _selectedParty = party;
              _partyController.text = party.name;
            });
          }
        });
      } catch (_) {}
    }

    return Container(
      width: 620,
      constraints: const BoxConstraints(maxHeight: 750),
      decoration: BoxDecoration(
        color: const Color(
          0xFFFAF6EE,
        ), // Sleek warm beige background matching the screenshot
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5DEC9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(28.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Row: Title & Pickers
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Add Entry',
                      style: GoogleFonts.montserrat(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF01565B), // Deep teal
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Record transaction details.',
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        color: const Color(0xFF5E543F).withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    _buildDateTimePicker(
                      icon: Icons.calendar_today_outlined,
                      text: DateFormat('dd MMM yyyy').format(_selectedDate),
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() => _selectedDate = picked);
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildDateTimePicker(
                      icon: Icons.access_time_outlined,
                      text: _selectedTime.format(context),
                      onTap: () async {
                        final TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: _selectedTime,
                        );
                        if (picked != null) {
                          setState(() => _selectedTime = picked);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // IN / OUT Toggle
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF4EDE4),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTransactionTypeButton(
                      title: 'IN (Receive)',
                      icon: Icons.arrow_downward,
                      selectedColor: const Color(0xFF01565B),
                      isSelected: _transactionType == 'IN',
                      onTap: () => setState(() => _transactionType = 'IN'),
                    ),
                  ),
                  Expanded(
                    child: _buildTransactionTypeButton(
                      title: 'OUT (Give)',
                      icon: Icons.arrow_upward,
                      selectedColor: const Color(0xFFC62828),
                      isSelected: _transactionType == 'OUT',
                      onTap: () => setState(() => _transactionType = 'OUT'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Party / Customer Selector Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Party / Customer',
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF5E543F),
                  ),
                ),
                InkWell(
                  onTap: () async {
                    final newId = await showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => const QuickAddPartyBottomSheet(),
                    );
                    if (newId != null && newId is String) {
                      final list = ref.read(partiesStreamProvider).value ?? [];
                      final found = list.where((p) => p.id == newId).firstOrNull;
                      if (found != null) {
                        setState(() {
                          _selectedParty = found;
                          _partyController.text = found.name;
                          _pendingPartyId = null;
                        });
                      } else {
                        setState(() => _pendingPartyId = newId);
                      }
                    }
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFDFBA6B)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.add,
                          size: 16,
                          color: Color(0xFF735C0F),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Add New',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF735C0F),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildPartyAutocomplete(),
            const SizedBox(height: 20),

            // Category Toggle
            Text(
              'Category',
              style: GoogleFonts.montserrat(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF5E543F),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF4EDE4),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  _buildCategoryButton('Money'),
                  _buildCategoryButton('Gold'),
                  _buildCategoryButton('Diamond'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Dynamic Form Fields based on Category
            if (_category == 'Money') ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFE5DEC9).withOpacity(0.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Mode',
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF5E543F),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildPaymentModeChip('Cash'),
                        const SizedBox(width: 12),
                        _buildPaymentModeChip('UPI'),
                        const SizedBox(width: 12),
                        _buildPaymentModeChip('RTGS'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Amount',
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF5E543F),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        _IndianCurrencyFormatter(),
                      ],
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        hintText: '0',
                        hintStyle: GoogleFonts.montserrat(
                          color: Colors.grey.shade300,
                          fontSize: 18,
                        ),
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(6.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4EDE4),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '₹',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF735C0F),
                              ),
                            ),
                          ),
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 0,
                          minHeight: 0,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade400),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade400),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFFDFBA6B),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_category == 'Gold') ...[
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Purity %',
                          style: GoogleFonts.montserrat(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF5E543F),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _purityController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textAlign: TextAlign.right,
                          style: GoogleFonts.montserrat(fontSize: 15),
                          decoration: InputDecoration(
                            hintText: '99.5',
                            hintStyle: GoogleFonts.montserrat(
                              color: Colors.grey.shade400,
                              fontSize: 15,
                            ),
                            suffixIcon: Padding(
                              padding: const EdgeInsets.only(right: 12.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '%',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 16,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            suffixIconConstraints: const BoxConstraints(
                              minWidth: 0,
                              minHeight: 0,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFFDFBA6B),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Weight (g)',
                          style: GoogleFonts.montserrat(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF5E543F),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _weightController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textAlign: TextAlign.right,
                          style: GoogleFonts.montserrat(fontSize: 15),
                          decoration: InputDecoration(
                            hintText: '0.00',
                            hintStyle: GoogleFonts.montserrat(
                              color: Colors.grey.shade400,
                              fontSize: 15,
                            ),
                            suffixIcon: Padding(
                              padding: const EdgeInsets.only(right: 12.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'g',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 16,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            suffixIconConstraints: const BoxConstraints(
                              minWidth: 0,
                              minHeight: 0,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFFDFBA6B),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ] else if (_category == 'Diamond') ...[
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CARAT (CT)',
                          style: GoogleFonts.montserrat(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF5E543F),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _caratController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            hintText: '0.00',
                            hintStyle: GoogleFonts.montserrat(
                              color: Colors.grey.shade400,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFFDFBA6B),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PIECES',
                          style: GoogleFonts.montserrat(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF5E543F),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _piecesController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            hintText: '0',
                            hintStyle: GoogleFonts.montserrat(
                              color: Colors.grey.shade400,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFFDFBA6B),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),

            // Particulars / Notes
            Text(
              'Particulars / Notes',
              style: GoogleFonts.montserrat(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF5E543F),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 2,
              style: GoogleFonts.montserrat(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Add details about the transaction...',
                hintStyle: GoogleFonts.montserrat(color: Colors.grey.shade500),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFDFBA6B)),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(0xFFF4EDE4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.montserrat(
                        color: Colors.black87,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveTransaction,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(0xFFDFBA6B), // Gold
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Color(0xFF01565B),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.check,
                                color: Color(0xFF01565B),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Save Entry',
                                style: GoogleFonts.montserrat(
                                  color: const Color(0xFF01565B),
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimePicker({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5DEC9)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: const Color(0xFF5E543F)),
            const SizedBox(width: 6),
            Text(
              text,
              style: GoogleFonts.montserrat(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF5E543F),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionTypeButton({
    required String title,
    required IconData icon,
    required Color selectedColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? const Color(0xFFE5DEC9) : Colors.transparent,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? selectedColor : const Color(0xFF5E543F),
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.montserrat(
                color: isSelected ? selectedColor : const Color(0xFF5E543F),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryButton(String categoryName) {
    final isSelected = _category == categoryName;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _category = categoryName),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              categoryName,
              style: GoogleFonts.montserrat(
                color: isSelected
                    ? const Color(0xFF01565B)
                    : const Color(0xFF5E543F),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentModeChip(String mode) {
    final isSelected = _paymentMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _paymentMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF9E6) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFDFBA6B)
                : const Color(0xFFE5DEC9),
          ),
        ),
        child: Text(
          mode,
          style: GoogleFonts.montserrat(
            color: isSelected
                ? const Color(0xFF735C0F)
                : const Color(0xFF5E543F),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildPartyAutocomplete() {
    return LayoutBuilder(
      builder: (context, constraints) => RawAutocomplete<PartyModel>(
        focusNode: _partyFocusNode,
        textEditingController: _partyController,
        optionsBuilder: (TextEditingValue textEditingValue) {
          final query = textEditingValue.text.trim().toLowerCase();
          final parties = ref.read(partiesStreamProvider).value ?? [];

          if (query.isEmpty) {
            final recent = parties.toList()
              ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
            return recent.take(5);
          }

          final matches = parties.where((party) {
            return party.name.toLowerCase().contains(query) ||
                party.phone.contains(query);
          }).toList();

          return matches;
        },
        displayStringForOption: (PartyModel option) => option.name,
        onSelected: (PartyModel selection) {
          setState(() => _selectedParty = selection);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _partyFocusNode.unfocus();
          });
        },
        fieldViewBuilder:
            (context, textEditingController, focusNode, onFieldSubmitted) {
              return TextField(
                controller: textEditingController,
                focusNode: focusNode,
                style: GoogleFonts.montserrat(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search party name or phone...',
                  hintStyle: GoogleFonts.montserrat(
                    color: Colors.grey.shade500,
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF5E543F),
                    size: 18,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFDFBA6B)),
                  ),
                  suffixIcon:
                      _selectedParty != null ||
                          textEditingController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            textEditingController.clear();
                            setState(() => _selectedParty = null);
                          },
                        )
                      : null,
                ),
                onSubmitted: (String value) {
                  onFieldSubmitted();
                },
              );
            },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 8,
              shadowColor: Colors.black.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: 200,
                  maxWidth: constraints.maxWidth,
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (BuildContext context, int index) {
                    final option = options.elementAt(index);

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFF4EDE4),
                        radius: 16,
                        child: Text(
                          option.name.isNotEmpty
                              ? option.name[0].toUpperCase()
                              : '?',
                          style: GoogleFonts.montserrat(
                            color: const Color(0xFF735C0F),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      title: _buildHighlightText(
                        option.name,
                        _partyController.text,
                      ),
                      subtitle: option.phone.isNotEmpty
                          ? Text(
                              option.phone,
                              style: GoogleFonts.montserrat(fontSize: 11),
                            )
                          : null,
                      dense: true,
                      onTap: () => onSelected(option),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHighlightText(String text, String query) {
    if (query.isEmpty)
      return Text(
        text,
        style: GoogleFonts.montserrat(
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
      );
    final matchIndex = text.toLowerCase().indexOf(query.toLowerCase());
    if (matchIndex == -1)
      return Text(
        text,
        style: GoogleFonts.montserrat(
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
      );
    return RichText(
      text: TextSpan(
        text: text.substring(0, matchIndex),
        style: GoogleFonts.montserrat(
          color: Colors.black87,
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
        children: [
          TextSpan(
            text: text.substring(matchIndex, matchIndex + query.length),
            style: GoogleFonts.montserrat(
              color: const Color(0xFFDFBA6B),
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          TextSpan(
            text: text.substring(matchIndex + query.length),
            style: GoogleFonts.montserrat(
              color: Colors.black87,
              fontWeight: FontWeight.w500,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveTransaction() async {
    if (_selectedParty == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a party')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Determine TransactionType
      TransactionType tType = TransactionType.sale; // default
      if (_transactionType == 'IN') {
        if (_category == 'Money')
          tType = TransactionType.receipt;
        else
          tType = TransactionType.metalIn;
      } else {
        if (_category == 'Money')
          tType = TransactionType.payment;
        else
          tType = TransactionType.metalOut;
      }

      // Determine PaymentMode
      PaymentMode pMode = PaymentMode.cash;
      if (_category == 'Money') {
        if (_paymentMode == 'Cash')
          pMode = PaymentMode.cash;
        else if (_paymentMode == 'UPI')
          pMode = PaymentMode.upi;
        else if (_paymentMode == 'RTGS')
          pMode = PaymentMode.rtgs;
      } else {
        pMode = PaymentMode.metal;
      }

      // Parse values
      double cashAmt =
          double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0.0;
      double metalWt = 0.0;
      if (_category == 'Gold')
        metalWt = double.tryParse(_weightController.text) ?? 0.0;
      if (_category == 'Diamond')
        metalWt = double.tryParse(_caratController.text) ?? 0.0;

      String metalP = '';
      if (_category == 'Gold') metalP = _purityController.text.trim();
      if (_category == 'Diamond') metalP = '${_piecesController.text.trim()} p';

      final date = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final success = await ref
          .read(transactionNotifierProvider.notifier)
          .createTransaction(
            partyId: _selectedParty!.id,
            partyName: _selectedParty!.name,
            partyPhone: _selectedParty!.phone,
            type: tType,
            paymentMode: pMode,
            cashAmount: cashAmt,
            metalType: _category == 'Money' ? '' : _category.toLowerCase(),
            metalWeight: metalWt,
            metalPurity: metalP,
            notes: _notesController.text.trim(),
            date: date,
          );

      if (success && mounted) {
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quick Entry saved successfully')),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to save entry')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('An error occurred while saving')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }


}

class _IndianCurrencyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    String cleanText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanText.isEmpty) {
      return newValue.copyWith(text: '');
    }

    try {
      int value = int.parse(cleanText);
      final formatter = NumberFormat.decimalPattern('en_IN');
      String formattedText = formatter.format(value);

      return newValue.copyWith(
        text: formattedText,
        selection: TextSelection.collapsed(offset: formattedText.length),
      );
    } catch (e) {
      return oldValue;
    }
  }
}
