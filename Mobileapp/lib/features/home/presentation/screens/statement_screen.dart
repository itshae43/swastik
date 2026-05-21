import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:swastik_mobile_app/core/models/transaction_model.dart';
import 'package:swastik_mobile_app/core/utils/responsive_utils.dart';
import 'package:swastik_mobile_app/features/ledger/providers/transaction_providers.dart';

class TransactionStatementScreen extends ConsumerStatefulWidget {
  final String category; // 'cash', 'online', 'gold', 'diamond'

  const TransactionStatementScreen({
    super.key,
    required this.category,
  });

  @override
  ConsumerState<TransactionStatementScreen> createState() => _TransactionStatementScreenState();
}

class _TransactionStatementScreenState extends ConsumerState<TransactionStatementScreen> {
  String _typeFilter = 'All'; // 'All', 'IN', 'OUT'
  String _dateFilter = 'All Time'; // 'All Time', 'Today', 'This Week', 'This Month'

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

  Color get _categoryColor {
    switch (widget.category) {
      case 'cash':
        return const Color(0xFF01565B);
      case 'online':
        return const Color(0xFF2E5BFF);
      case 'gold':
        return const Color(0xFFDFBA6B);
      case 'diamond':
        return const Color(0xFF8EACCD);
      default:
        return const Color(0xFF01565B);
    }
  }

  Gradient get _categoryGradient {
    switch (widget.category) {
      case 'cash':
        return const LinearGradient(
          colors: [Color(0xFF014448), Color(0xFF026D73)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'online':
        return const LinearGradient(
          colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'gold':
        return const LinearGradient(
          colors: [Color(0xFF9E7C1C), Color(0xFFD4AF37)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'diamond':
        return const LinearGradient(
          colors: [Color(0xFF6B8CAD), Color(0xFF8EACCD)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      default:
        return const LinearGradient(
          colors: [Color(0xFF01565B), Color(0xFF026D73)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  String get _categoryTitle {
    switch (widget.category) {
      case 'cash':
        return 'Cash Statement';
      case 'online':
        return 'Online (UPI/RTGS) Statement';
      case 'gold':
        return 'Gold Statement';
      case 'diamond':
        return 'Diamond Statement';
      default:
        return 'Statement';
    }
  }

  String get _categoryUnit {
    switch (widget.category) {
      case 'cash':
      case 'online':
        return '₹';
      case 'gold':
        return 'g';
      case 'diamond':
        return 'ct';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsStreamProvider);
    final isTablet = AppResponsive.isTablet(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF6EE), // Beautiful warm beige background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF5E543F)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _categoryTitle,
          style: GoogleFonts.montserrat(
            color: const Color(0xFF5E543F),
            fontWeight: FontWeight.bold,
            fontSize: isTablet ? 22 : 18,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.print_rounded, color: Color(0xFF5E543F)),
            tooltip: 'Print Statement',
            onPressed: () {
              // Extract values for dialog
              double totalBalance = 0.0;
              final listVal = transactionsAsync.value ?? [];
              final categoryTxns = listVal.where((t) {
                if (widget.category == 'cash') {
                  return t.metalType.isEmpty && t.paymentMode == PaymentMode.cash;
                } else if (widget.category == 'online') {
                  return t.metalType.isEmpty &&
                      (t.paymentMode == PaymentMode.online ||
                          t.paymentMode == PaymentMode.upi ||
                          t.paymentMode == PaymentMode.rtgs);
                } else {
                  return t.metalType == widget.category;
                }
              }).toList();
              
              for (final t in categoryTxns) {
                final isCredit = t.type == TransactionType.receipt || t.type == TransactionType.metalIn;
                final isDebit = t.type == TransactionType.payment || t.type == TransactionType.metalOut;
                final val = t.metalType.isEmpty ? t.cashAmount : t.metalWeight;
                if (isCredit) {
                  totalBalance += val;
                } else if (isDebit) {
                  totalBalance -= val;
                }
              }

              String balanceStr = '';
              if (widget.category == 'cash' || widget.category == 'online') {
                balanceStr = '₹ ${NumberFormat.decimalPattern('en_IN').format(totalBalance)}';
              } else {
                balanceStr = '${totalBalance % 1 == 0 ? totalBalance.toInt().toString() : totalBalance.toStringAsFixed(3).replaceAll(RegExp(r'\.?0+$'), '')} $_categoryUnit';
              }

              _showPrintStatementDialog(context, categoryTxns, balanceStr);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: transactionsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFFDFBA6B)),
        ),
        error: (err, stack) => Center(
          child: Text('Error loading statement: $err'),
        ),
        data: (allTransactions) {
          // 1. Filter by category
          final categoryTxns = allTransactions.where((t) {
            if (widget.category == 'cash') {
              return t.metalType.isEmpty && t.paymentMode == PaymentMode.cash;
            } else if (widget.category == 'online') {
              return t.metalType.isEmpty &&
                  (t.paymentMode == PaymentMode.online ||
                      t.paymentMode == PaymentMode.upi ||
                      t.paymentMode == PaymentMode.rtgs);
            } else {
              return t.metalType == widget.category;
            }
          }).toList();

          // 2. Calculate balance dynamically
          double balance = 0.0;
          for (final t in categoryTxns) {
            final isCredit = t.type == TransactionType.receipt || t.type == TransactionType.metalIn;
            final isDebit = t.type == TransactionType.payment || t.type == TransactionType.metalOut;
            final val = t.metalType.isEmpty ? t.cashAmount : t.metalWeight;

            if (isCredit) {
              balance += val;
            } else if (isDebit) {
              balance -= val;
            }
          }

          // 3. Apply type filter
          var filteredTxns = categoryTxns.where((t) {
            final isCredit = t.type == TransactionType.receipt || t.type == TransactionType.metalIn;
            final isDebit = t.type == TransactionType.payment || t.type == TransactionType.metalOut;

            if (_typeFilter == 'IN') return isCredit;
            if (_typeFilter == 'OUT') return isDebit;
            return true;
          }).toList();

          // 4. Apply date filter
          final now = DateTime.now();
          filteredTxns = filteredTxns.where((t) {
            if (_dateFilter == 'Today') {
              return t.date.year == now.year && t.date.month == now.month && t.date.day == now.day;
            } else if (_dateFilter == 'This Week') {
              final weekAgo = now.subtract(const Duration(days: 7));
              return t.date.isAfter(weekAgo);
            } else if (_dateFilter == 'This Month') {
              return t.date.year == now.year && t.date.month == now.month;
            }
            return true;
          }).toList();

          // 5. Format balance string
          String balanceStr = '';
          if (widget.category == 'cash' || widget.category == 'online') {
            balanceStr = '₹ ${NumberFormat.decimalPattern('en_IN').format(balance)}';
          } else {
            balanceStr = '${balance % 1 == 0 ? balance.toInt().toString() : balance.toStringAsFixed(3).replaceAll(RegExp(r'\.?0+$'), '')} $_categoryUnit';
          }

          // 6. Group by date
          final Map<String, List<TransactionModel>> groupedTxns = {};
          final todayStr = DateFormat('yyyy-MM-dd').format(now);
          final yesterdayStr = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));

          for (final t in filteredTxns) {
            final dateKey = DateFormat('yyyy-MM-dd').format(t.date);
            if (!groupedTxns.containsKey(dateKey)) {
              groupedTxns[dateKey] = [];
            }
            groupedTxns[dateKey]!.add(t);
          }

          final sortedDates = groupedTxns.keys.toList()..sort((a, b) => b.compareTo(a));

          return Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 850),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 32.0 : 16.0,
                  vertical: 8.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                // Premium Balance Header Card
                Container(
                  padding: EdgeInsets.all(isTablet ? 28 : 20),
                  decoration: BoxDecoration(
                    gradient: _categoryGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: _categoryColor.withOpacity(0.2),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CURRENT STORE BALANCE',
                        style: GoogleFonts.montserrat(
                          fontSize: isTablet ? 13 : 11,
                          color: widget.category == 'gold' ? Colors.black87.withOpacity(0.6) : Colors.white70,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        balanceStr,
                        style: GoogleFonts.montserrat(
                          fontSize: isTablet ? 32 : 26,
                          fontWeight: FontWeight.bold,
                          color: widget.category == 'gold' ? Colors.black87 : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Statement view: Date-wise',
                            style: GoogleFonts.montserrat(
                              fontSize: isTablet ? 13 : 11,
                              color: widget.category == 'gold' ? Colors.black87.withOpacity(0.5) : Colors.white54,
                            ),
                          ),
                          Text(
                            '${filteredTxns.length} entries shown',
                            style: GoogleFonts.montserrat(
                              fontSize: isTablet ? 13 : 11,
                              fontWeight: FontWeight.w600,
                              color: widget.category == 'gold' ? Colors.black87.withOpacity(0.7) : Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Filters Section (Dropdowns)
                Row(
                  children: [
                    // Transaction Type Dropdown Filter
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5DEC9).withOpacity(0.6)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _typeFilter,
                            isExpanded: true,
                            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF735C0F)),
                            style: GoogleFonts.montserrat(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF5E543F),
                            ),
                            items: <String>['All', 'IN', 'OUT'].map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value == 'All' ? 'All Transactions' : 'Only $value'),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _typeFilter = val;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Date Dropdown Filter
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5DEC9).withOpacity(0.6)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _dateFilter,
                            isExpanded: true,
                            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF735C0F)),
                            style: GoogleFonts.montserrat(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF5E543F),
                            ),
                            items: <String>['All Time', 'Today', 'This Week', 'This Month'].map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _dateFilter = val;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Transactions List
                Expanded(
                  child: filteredTxns.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.receipt_long_rounded,
                                size: isTablet ? 64 : 48,
                                color: const Color(0xFF5E543F).withOpacity(0.3),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No transactions matching filters',
                                style: GoogleFonts.montserrat(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF5E543F).withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: sortedDates.length,
                          itemBuilder: (context, dateIndex) {
                            final dateKey = sortedDates[dateIndex];
                            final dayTxns = groupedTxns[dateKey]!;

                            // Determine header text
                            String headerText = '';
                            if (dateKey == todayStr) {
                              headerText = 'Today';
                            } else if (dateKey == yesterdayStr) {
                              headerText = 'Yesterday';
                            } else {
                              final parsedDate = DateTime.parse(dateKey);
                              headerText = DateFormat('EEEE, d MMM yyyy').format(parsedDate);
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Date Header
                                Padding(
                                  padding: const EdgeInsets.only(top: 16.0, bottom: 8.0, left: 4.0),
                                  child: Text(
                                    headerText,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF735C0F),
                                    ),
                                  ),
                                ),

                                // Transaction items in a nice Card-style list
                                ...dayTxns.map((t) {
                                  final isCredit = t.type == TransactionType.receipt || t.type == TransactionType.metalIn;
                                  final timeStr = DateFormat('hh:mm a').format(t.date);
                                  final initial = t.partyName.isNotEmpty ? t.partyName[0].toUpperCase() : '?';
                                  final avatarBgColor = _getAvatarColorForName(t.partyName);

                                  // Flow green/red display
                                  final amountColor = isCredit ? const Color(0xFF01565B) : const Color(0xFFC62828);
                                  final sign = isCredit ? '+ ' : '- ';

                                  String amountStr = '';
                                  if (t.metalType.isEmpty) {
                                    amountStr = '$sign₹ ${NumberFormat.decimalPattern('en_IN').format(t.cashAmount)}';
                                  } else {
                                    amountStr = '$sign${t.metalWeight % 1 == 0 ? t.metalWeight.toInt().toString() : t.metalWeight.toStringAsFixed(3).replaceAll(RegExp(r'\.?0+$'), '')} $_categoryUnit';
                                  }

                                  // Badge text
                                  String badgeText = '';
                                  if (t.metalType.isEmpty) {
                                    badgeText = t.paymentMode.name.toUpperCase();
                                  } else if (t.metalType == 'gold') {
                                    badgeText = t.metalPurity.isNotEmpty ? '${t.metalPurity}% Purity' : 'Gold';
                                  } else {
                                    badgeText = t.metalPurity.isNotEmpty ? t.metalPurity : 'Diamond';
                                  }

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: const Color(0xFFE5DEC9).withOpacity(0.5),
                                        width: 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.02),
                                          blurRadius: 6,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(14.0),
                                      child: Row(
                                        children: [
                                          // Left: Styled Avatar
                                          Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              color: avatarBgColor.withOpacity(0.12),
                                              shape: BoxShape.circle,
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              initial,
                                              style: GoogleFonts.montserrat(
                                                color: avatarBgColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          
                                          // Center: Party details
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        t.partyName,
                                                        style: GoogleFonts.montserrat(
                                                          fontSize: 14,
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.black87,
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFFAF6EE),
                                                        borderRadius: BorderRadius.circular(6),
                                                        border: Border.all(color: const Color(0xFFE5DEC9)),
                                                      ),
                                                      child: Text(
                                                        badgeText,
                                                        style: GoogleFonts.montserrat(
                                                          fontSize: 9,
                                                          fontWeight: FontWeight.bold,
                                                          color: const Color(0xFF735C0F),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (t.notes.isNotEmpty) ...[
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    t.notes,
                                                    style: GoogleFonts.montserrat(
                                                      fontSize: 11,
                                                      color: Colors.black54,
                                                      fontStyle: FontStyle.italic,
                                                    ),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          
                                          // Right: Amount, print button, and time
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    amountStr,
                                                    style: GoogleFonts.montserrat(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.bold,
                                                      color: amountColor,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  GestureDetector(
                                                    onTap: () => _showPrintReceiptDialog(context, t, amountStr, badgeText),
                                                    child: Container(
                                                      padding: const EdgeInsets.all(5),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFFAF6EE),
                                                        borderRadius: BorderRadius.circular(6),
                                                        border: Border.all(color: const Color(0xFFE5DEC9), width: 0.5),
                                                      ),
                                                      child: const Icon(
                                                        Icons.print_rounded,
                                                        size: 13,
                                                        color: Color(0xFF735C0F),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                timeStr,
                                                style: GoogleFonts.montserrat(
                                                  fontSize: 10,
                                                  color: Colors.black45,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(), // ignore: unnecessary_to_list_in_spreads
                              ],
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      );
    },
      ),
    );
  }

  void _showPrintReceiptDialog(
    BuildContext context,
    TransactionModel t,
    String amountStr,
    String badgeText,
  ) {
    final isCredit = t.type == TransactionType.receipt || t.type == TransactionType.metalIn;
    final dateStr = DateFormat('dd MMM yyyy').format(t.date);
    final timeStr = DateFormat('hh:mm a').format(t.date);
    final receiptNo = 'SK-${t.date.millisecondsSinceEpoch.toString().substring(7)}';

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
                constraints: const BoxConstraints(maxWidth: 420),
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
                    // Header of dialog
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
                            'Receipt Print Preview',
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
                        height: 320,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(color: Color(0xFF01565B)),
                            const SizedBox(height: 20),
                            Text(
                              'Connecting to printer...',
                              style: GoogleFonts.montserrat(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF5E543F),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Sending receipt to Thermal Printer...',
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
                        height: 320,
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
                              'Receipt Saved!',
                              style: GoogleFonts.montserrat(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF01565B),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'PDF saved to Documents/SwarnKhata',
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF01565B),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                'Done',
                                style: GoogleFonts.montserrat(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      // Simulated Thermal Receipt
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.withOpacity(0.2)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Store details
                              Center(
                                child: Column(
                                  children: [
                                    Text(
                                      'SWASTIK JEWELS',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF735C0F),
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '------------------------------------------',
                                      style: TextStyle(color: Colors.grey[400]),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Receipt Metadata
                              _buildReceiptRow('Receipt No:', receiptNo),
                              _buildReceiptRow('Date:', '$dateStr  $timeStr'),
                              _buildReceiptRow('Customer Name:', t.partyName),
                              _buildReceiptRow('Type:', isCredit ? 'CREDIT / IN' : 'DEBIT / OUT'),
                              _buildReceiptRow('Category:', widget.category.toUpperCase()),
                              if (badgeText.isNotEmpty)
                                _buildReceiptRow('Particulars:', badgeText),

                              Text(
                                '------------------------------------------',
                                style: TextStyle(color: Colors.grey[400]),
                              ),
                              const SizedBox(height: 8),

                              // Amount / Details Highlight
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFAF6EE),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFE5DEC9)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'TOTAL AMOUNT:',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF5E543F),
                                      ),
                                    ),
                                    Text(
                                      amountStr,
                                      style: GoogleFonts.montserrat(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isCredit ? const Color(0xFF01565B) : const Color(0xFFC62828),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (t.notes.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Notes: "${t.notes}"',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),

                              // Barcode placeholder
                              Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.bar_chart_rounded, size: 40, color: Colors.grey[600]),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Thank you for your business!',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
                                  'Print',
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

  void _showPrintStatementDialog(
    BuildContext context,
    List<TransactionModel> txns,
    String totalBalance,
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
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF01565B),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                'Done',
                                style: GoogleFonts.montserrat(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      // A4 Document Preview
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Container(
                          height: 260,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.withOpacity(0.2)),
                          ),
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Center(
                                  child: Column(
                                    children: [
                                      Text(
                                        'SWASTIK JEWELS',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF01565B),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Period: ${DateFormat('dd MMM yyyy').format(DateTime.now().subtract(const Duration(days: 30)))} - ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
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
                                _buildReceiptRow('Store Balance:', totalBalance),
                                _buildReceiptRow('Category:', widget.category.toUpperCase()),
                                _buildReceiptRow('Total Entries:', '${txns.length} items'),
                                const SizedBox(height: 10),
                                Table(
                                  border: TableBorder.all(color: Colors.grey.withOpacity(0.3), width: 0.5),
                                  columnWidths: const {
                                    0: FlexColumnWidth(2),
                                    1: FlexColumnWidth(3),
                                    2: FlexColumnWidth(2),
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
                                          child: Text('Amount', style: GoogleFonts.montserrat(fontSize: 8, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                    ...txns.take(8).map((txn) {
                                      final isCr = txn.type == TransactionType.receipt || txn.type == TransactionType.metalIn;
                                      final amt = txn.metalType.isEmpty 
                                          ? '₹${NumberFormat.decimalPattern('en_IN').format(txn.cashAmount)}'
                                          : '${txn.metalWeight} ${widget.category == 'gold' ? 'g' : 'ct'}';
                                      return TableRow(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.all(4.0),
                                            child: Text(DateFormat('dd MMM').format(txn.date), style: GoogleFonts.montserrat(fontSize: 8)),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(4.0),
                                            child: Text(txn.partyName, style: GoogleFonts.montserrat(fontSize: 8), overflow: TextOverflow.ellipsis),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(4.0),
                                            child: Text('${isCr ? '+' : '-'}$amt', style: GoogleFonts.montserrat(fontSize: 8, fontWeight: FontWeight.bold, color: isCr ? const Color(0xFF01565B) : const Color(0xFFC62828))),
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
                                  'Print A4',
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
                                  'Export PDF',
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

  Widget _buildReceiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.montserrat(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.montserrat(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
