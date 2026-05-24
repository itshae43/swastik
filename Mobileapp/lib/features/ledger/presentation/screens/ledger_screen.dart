import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:swastik_mobile_app/core/models/party_model.dart';
import 'package:swastik_mobile_app/core/models/transaction_model.dart';
import 'package:swastik_mobile_app/core/utils/responsive_utils.dart';
import 'package:swastik_mobile_app/core/utils/communication_utils.dart';
import 'package:swastik_mobile_app/features/parties/providers/party_providers.dart';
import 'package:swastik_mobile_app/features/ledger/providers/transaction_providers.dart';
import '../../../parties/presentation/screens/party_detail_screen.dart';
import 'package:swastik_mobile_app/core/services/pdf_service.dart';

class LedgerScreen extends ConsumerStatefulWidget {
  const LedgerScreen({super.key});

  @override
  ConsumerState<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends ConsumerState<LedgerScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = AppResponsive.isTablet(context);
    final partiesAsync = ref.watch(partiesStreamProvider);
    final transactionsAsync = ref.watch(transactionsStreamProvider);

    return Container(
      color: isTablet ? const Color(0xFFFAF6EE) : const Color(0xFFFDFBF7),
      child: SafeArea(
        child: partiesAsync.when(
          data: (parties) {
            final transactions = transactionsAsync.value ?? [];

            // Apply Search Query
            final query = _searchQuery.toLowerCase().trim();

            // Sort parties alphabetically by name (A to Z)
            final List<PartyModel> sortedParties = List.from(parties)
              ..sort(
                (a, b) => a.name.trim().toLowerCase().compareTo(
                  b.name.trim().toLowerCase(),
                ),
              );

            // Filter by search query
            final List<PartyModel> filteredParties = sortedParties.where((p) {
              if (query.isEmpty) return true;
              return p.name.toLowerCase().contains(query) ||
                  p.phone.toLowerCase().contains(query);
            }).toList();

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 28.0 : 16.0,
                vertical: isTablet ? 22.0 : 16.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSearchBar(isTablet),
                  SizedBox(height: isTablet ? 24 : 16),
                  _buildRecentActivityHeader(isTablet),
                  SizedBox(height: isTablet ? 24 : 16),
                  _buildPartiesList(filteredParties, isTablet, transactions),
                  const SizedBox(height: 80), // Padding for bottom nav
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error loading ledger: $e')),
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isTablet) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isTablet ? 32 : 24),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        style: GoogleFonts.montserrat(fontSize: isTablet ? 16 : 15),
        decoration: InputDecoration(
          hintText: 'Search customers by name or phone...',
          hintStyle: GoogleFonts.montserrat(
            color: Colors.grey[500],
            fontSize: isTablet ? 16 : 15,
          ),
          prefixIcon: Padding(
            padding: EdgeInsets.symmetric(horizontal: isTablet ? 16 : 12),
            child: Icon(
              Icons.search,
              color: Colors.grey[600],
              size: isTablet ? 25 : 24,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 0,
            minHeight: 0,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                  child: Padding(
                    padding: EdgeInsets.only(right: isTablet ? 16 : 12),
                    child: Icon(
                      Icons.clear,
                      color: Colors.grey[600],
                      size: isTablet ? 24 : 20,
                    ),
                  ),
                )
              : null,
          suffixIconConstraints: const BoxConstraints(
            minWidth: 0,
            minHeight: 0,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: isTablet ? 24 : 20,
            vertical: isTablet ? 18 : 14,
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivityHeader(bool isTablet) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "Customers",
          style: GoogleFonts.montserrat(
            fontSize: isTablet ? 21 : 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildPartiesList(
    List<PartyModel> filteredParties,
    bool isTablet,
    List<TransactionModel> transactions,
  ) {
    if (filteredParties.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.people_outline,
                size: isTablet ? 80 : 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No customers found',
                style: GoogleFonts.montserrat(
                  fontSize: isTablet ? 18 : 16,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: filteredParties
          .map((party) => _buildPartyCard(party, isTablet, transactions))
          .toList(),
    );
  }

  Widget _buildPartyCard(
    PartyModel party,
    bool isTablet,
    List<TransactionModel> transactions,
  ) {


    Color leftBorderColor = const Color(0xFFDFBA6B); // Premium brand gold
    if (party.cashBalance > 0 ||
        party.goldBalanceGrams > 0 ||
        party.diamondBalanceCarats > 0) {
      leftBorderColor = const Color(0xFF2852C6); // Receivable Blue
    } else if (party.cashBalance < 0 ||
        party.goldBalanceGrams < 0 ||
        party.diamondBalanceCarats < 0) {
      leftBorderColor = const Color(0xFFC62828); // Payable Red
    }

    final initial = party.name.isNotEmpty ? party.name[0].toUpperCase() : '?';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                PartyDetailScreen(party: _getPartyDetail(party)),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: isTablet ? 16 : 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.grey.withOpacity(0.12)),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: isTablet ? 6 : 4,
                decoration: BoxDecoration(
                  color: leftBorderColor,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(isTablet ? 20 : 16),
                    bottomLeft: Radius.circular(isTablet ? 20 : 16),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(isTablet ? 20.0 : 16.0),
                  child: Row(
                    children: [
                      Container(
                        width: isTablet ? 58 : 54,
                        height: isTablet ? 58 : 54,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF0EBE1),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initial,
                          style: GoogleFonts.montserrat(
                            fontSize: isTablet ? 23 : 22,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF6B5800),
                          ),
                        ),
                      ),
                      SizedBox(width: isTablet ? 20 : 16),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              party.name,
                              style: GoogleFonts.montserrat(
                                fontSize: isTablet ? 18 : 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            if (!isTablet) ...[
                              const SizedBox(height: 4),
                              InkWell(
                                onTap: party.phone.isNotEmpty
                                    ? () => CommunicationUtils.makeCall(party.phone)
                                    : null,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.phone_outlined,
                                      size: 13,
                                      color: Colors.grey[500],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      party.phone.isNotEmpty
                                          ? party.phone
                                          : 'No Phone Number',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isTablet) ...[
                                InkWell(
                                  onTap: party.phone.isNotEmpty
                                      ? () => CommunicationUtils.makeCall(party.phone)
                                      : null,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF5EFE6),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.grey.withOpacity(0.2),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.phone_outlined,
                                          size: 16,
                                          color: Color(0xFF6B5800),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          party.phone.isNotEmpty
                                              ? party.phone
                                              : 'No Phone Number',
                                          style: GoogleFonts.montserrat(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF6B5800),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                GestureDetector(
                                  onTap: () {
                                    final partyTxns = transactions
                                        .where((t) => t.partyId == party.id)
                                        .toList();
                                    _showPrintCustomerLedgerDialog(context, party, partyTxns);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF5EFE6),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.grey.withOpacity(0.2),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.print_rounded,
                                      size: 18,
                                      color: Color(0xFF6B5800),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ] else ...[
                                GestureDetector(
                                  onTap: () {
                                    final partyTxns = transactions
                                        .where((t) => t.partyId == party.id)
                                        .toList();
                                    _showPrintCustomerLedgerDialog(context, party, partyTxns);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF5EFE6),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.grey.withOpacity(0.2),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.print_rounded,
                                      size: 14,
                                      color: Color(0xFF6B5800),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.grey[400],
                                size: isTablet ? 24 : 20,
                              ),
                            ],
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
      ),
    );
  }

  PartyDetail _getPartyDetail(PartyModel party) {
    final name = party.name;
    final type = party.type;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    String location = party.address.isNotEmpty
        ? party.address.split(',').last.trim()
        : 'India';

    List<PartyTransaction> transactions = [];

    String totalCashDue =
        '₹${NumberFormat.decimalPattern('en_IN').format(party.cashBalance.abs())}';
    String cashDueLabel = party.cashBalance >= 0 ? 'In' : 'Out';
    bool isCashYouOwe = party.cashBalance < 0;

    String totalGoldDue =
        '${party.goldBalanceGrams.abs().toStringAsFixed(3)} g';
    String goldDueLabel = party.goldBalanceGrams >= 0 ? 'In' : 'Out';
    bool isGoldYouOwe = party.goldBalanceGrams < 0;

    return PartyDetail(
      id: party.id,
      name: name,
      type: type,
      location: location,
      initial: initial,
      totalCashDue: totalCashDue,
      cashDueLabel: cashDueLabel,
      isCashYouOwe: isCashYouOwe,
      totalGoldDue: totalGoldDue,
      goldDueLabel: goldDueLabel,
      isGoldYouOwe: isGoldYouOwe,
      phone: party.phone,
      transactions: transactions,
    );
  }

  void _showPrintCustomerLedgerDialog(
    BuildContext context,
    PartyModel party,
    List<TransactionModel> txns,
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
                          Expanded(
                            child: Text(
                              'Print Customer Ledger',
                              style: GoogleFonts.montserrat(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
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
                              'Preparing ledger statement...',
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
                              'Ledger Saved!',
                              style: GoogleFonts.montserrat(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF01565B),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'PDF saved to Downloads folder',
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
                          height: 300,
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
                                        'CUSTOMER STATEMENT',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey[600],
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Divider(height: 1, color: Colors.grey[300]),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _buildLedgerReceiptRow('Customer Name:', party.name),
                                if (party.phone.isNotEmpty)
                                  _buildLedgerReceiptRow('Phone Number:', party.phone),
                                if (party.address.isNotEmpty)
                                  _buildLedgerReceiptRow('Address:', party.address),
                                const SizedBox(height: 8),
                                Text(
                                  'Outstanding Balances:',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF735C0F),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (party.cashBalance != 0)
                                  _buildLedgerReceiptRow(
                                    'Cash Balance:',
                                    '₹ ${NumberFormat.decimalPattern('en_IN').format(party.cashBalance.abs())} (${party.cashBalance >= 0 ? "In" : "Out"})',
                                  ),
                                if (party.goldBalanceGrams != 0)
                                  _buildLedgerReceiptRow(
                                    'Gold Balance:',
                                    '${party.goldBalanceGrams.abs().toStringAsFixed(3)} g (${party.goldBalanceGrams >= 0 ? "In" : "Out"})',
                                  ),
                                if (party.diamondBalanceCarats != 0)
                                  _buildLedgerReceiptRow(
                                    'Diamond Balance:',
                                    '${party.diamondBalanceCarats.abs().toStringAsFixed(3)} ct (${party.diamondBalanceCarats >= 0 ? "In" : "Out"})',
                                  ),
                                if (party.cashBalance == 0 &&
                                    party.goldBalanceGrams == 0 &&
                                    party.diamondBalanceCarats == 0)
                                  _buildLedgerReceiptRow('All Balances:', 'Settled'),
                                const SizedBox(height: 12),
                                if (txns.isNotEmpty) ...[
                                  Text(
                                    'Recent Transactions:',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF735C0F),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
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
                                            child: Text('Type / Mode', style: GoogleFonts.montserrat(fontSize: 8, fontWeight: FontWeight.bold)),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(4.0),
                                            child: Text('Amount', style: GoogleFonts.montserrat(fontSize: 8, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                      ...txns.take(8).map((txn) {
                                        final isCr = txn.type == TransactionType.receipt || txn.type == TransactionType.metalIn;
                                        String amt = '';
                                        if (txn.metalType.isEmpty) {
                                          amt = '₹${NumberFormat.decimalPattern('en_IN').format(txn.cashAmount)}';
                                        } else {
                                          amt = '${txn.metalWeight} ${txn.metalType == 'gold' ? 'g' : 'ct'}';
                                        }
                                        String typeMode = txn.typeLabel;
                                        if (txn.metalType.isEmpty) {
                                          typeMode += ' (${txn.paymentMode.name})';
                                        } else {
                                          typeMode += ' (${txn.metalType})';
                                        }
                                        return TableRow(
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.all(4.0),
                                              child: Text(DateFormat('dd MMM yyyy').format(txn.date), style: GoogleFonts.montserrat(fontSize: 8)),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.all(4.0),
                                              child: Text(typeMode, style: GoogleFonts.montserrat(fontSize: 8), overflow: TextOverflow.ellipsis),
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
                                ] else ...[
                                  Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 20),
                                      child: Text(
                                        'No transactions recorded for this customer.',
                                        style: GoogleFonts.montserrat(fontSize: 9, color: Colors.grey[500]),
                                      ),
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
                                onPressed: () async {
                                  setDialogState(() {
                                    isPrinting = true;
                                  });
                                  try {
                                    final pdfBytes = await PdfService.generateCustomerLedgerPdf(
                                      party: party,
                                      transactions: txns,
                                    );
                                    await PdfService.printPdf(pdfBytes);
                                    Navigator.pop(context);
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error printing: $e')),
                                    );
                                    setDialogState(() {
                                      isPrinting = false;
                                    });
                                  }
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
                                onPressed: () async {
                                  setDialogState(() {
                                    isPrinting = true;
                                  });
                                  try {
                                    final pdfBytes = await PdfService.generateCustomerLedgerPdf(
                                      party: party,
                                      transactions: txns,
                                    );
                                    final success = await PdfService.savePdfToDownloads(
                                      pdfBytes,
                                      'Ledger_${party.name}_${DateTime.now().millisecondsSinceEpoch}',
                                    );
                                    setDialogState(() {
                                      isPrinting = false;
                                      isSaved = success;
                                    });
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error saving PDF: $e')),
                                    );
                                    setDialogState(() {
                                      isPrinting = false;
                                    });
                                  }
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

  Widget _buildLedgerReceiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: GoogleFonts.montserrat(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.montserrat(
                fontSize: 10,
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
