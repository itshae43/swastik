import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swastik_mobile_app/core/models/party_model.dart';
import 'package:swastik_mobile_app/features/parties/providers/party_providers.dart';
import 'package:swastik_mobile_app/core/utils/responsive_utils.dart';
import 'party_detail_screen.dart';

class PartiesScreen extends ConsumerStatefulWidget {
  const PartiesScreen({super.key});

  @override
  ConsumerState<PartiesScreen> createState() => _PartiesScreenState();
}

class _PartiesScreenState extends ConsumerState<PartiesScreen> {
  String _selectedFilter = 'All Parties';
  final List<String> _filters = ['All Parties', 'Receivables (Dr)', 'Payables (Cr)', 'Net Position'];

  @override
  Widget build(BuildContext context) {
    final isTablet = AppResponsive.isTablet(context);
    return Container(
      color: isTablet ? const Color(0xFFFAF6EE) : const Color(0xFFFDFBF7),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSearchBar(),
              const SizedBox(height: 20),
              _buildFilterChips(),
              const SizedBox(height: 24),
              _buildPartiesList(),
              const SizedBox(height: 80), // Padding for bottom nav
            ],
          ),
        ),
      ),
    );
  }



  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search parties by name or ID...',
          hintStyle: GoogleFonts.montserrat(
            color: Colors.grey[500],
            fontSize: 15,
          ),
          prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _filters.map((filter) {
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedFilter = filter;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFD4B13B) : const Color(0xFFEBE3D5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  filter,
                  style: GoogleFonts.montserrat(
                    color: const Color(0xFF4A3E1F),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPartiesList() {
    final partiesAsync = ref.watch(partiesStreamProvider);

    return partiesAsync.when(
      data: (parties) {
        // Apply Filters
        List<PartyModel> filteredParties = parties;
        if (_selectedFilter == 'Receivables (Dr)') {
          filteredParties = parties.where((p) => p.cashBalance > 0 || p.goldBalanceGrams > 0).toList();
        } else if (_selectedFilter == 'Payables (Cr)') {
          filteredParties = parties.where((p) => p.cashBalance < 0 || p.goldBalanceGrams < 0).toList();
        }

        if (filteredParties.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(Icons.person_search_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No parties found',
                    style: GoogleFonts.montserrat(color: Colors.grey[500], fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredParties.length,
          itemBuilder: (context, index) {
            final party = filteredParties[index];
            return _buildPartyCard(party);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildPartyCard(PartyModel party) {
    // UI Logic for colors and icons based on type and balance
    final bool hasIcon = party.type == 'B2B Supplier' || party.type == 'Vendor';
    final Color avatarColor = hasIcon ? const Color(0xFFFFEEB3) : const Color(0xFFEBE3D5);
    final Color iconColor = const Color(0xFF4A3E1F);
    
    // Determine primary display amount (prefer cash if exists, otherwise gold)
    String displayAmount;
    Color amountColor;
    String status;
    Color statusColor;
    Color leftBorderColor;

    if (party.cashBalance != 0) {
      displayAmount = '₹${party.cashBalance.abs().toStringAsFixed(0)}';
      amountColor = const Color(0xFF1E1E1E);
      status = party.cashBalanceLabel;
      statusColor = party.cashBalance > 0 ? const Color(0xFF2852C6) : const Color(0xFFC62828);
      leftBorderColor = statusColor;
    } else if (party.goldBalanceGrams != 0) {
      displayAmount = '${party.goldBalanceGrams.abs().toStringAsFixed(3)}g';
      amountColor = const Color(0xFFC7A22A);
      status = party.goldBalanceLabel;
      statusColor = const Color(0xFF6B5800);
      leftBorderColor = const Color(0xFFC7A22A);
    } else {
      displayAmount = 'Settled';
      amountColor = Colors.grey;
      status = 'No Balance';
      statusColor = Colors.grey;
      leftBorderColor = Colors.grey[300]!;
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PartyDetailScreen(
              party: _getPartyDetail(party),
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 5,
                decoration: BoxDecoration(
                  color: leftBorderColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: avatarColor,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: hasIcon
                            ? Icon(Icons.workspace_premium_outlined, color: iconColor, size: 24)
                            : Text(
                                party.name.isNotEmpty ? party.name[0].toUpperCase() : '?',
                                style: GoogleFonts.montserrat(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500,
                                  color: iconColor,
                                ),
                              ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              party.name,
                              style: GoogleFonts.montserrat(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              party.type,
                              style: GoogleFonts.montserrat(
                                fontSize: 14,
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
                            displayAmount,
                            style: GoogleFonts.montserrat(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: amountColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            status,
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: statusColor,
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
      ),
    );
  }

  // ─── MAP PARTY DATA TO PARTY DETAIL MODEL ─────────────────────
  PartyDetail _getPartyDetail(PartyModel party) {
    final name = party.name;
    final type = party.type;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    // Determine location based on party type (mocking for now as address might be partial)
    String location = party.address.isNotEmpty 
        ? party.address.split(',').last.trim() 
        : 'India';

    // Generate personalized transactions based on the party (Still mock for now as transactions not implemented)
    List<PartyTransaction> transactions = [];

    // Map amounts from Model
    String totalCashDue = '₹${party.cashBalance.abs().toStringAsFixed(0)}';
    String cashDueLabel = party.cashBalance >= 0 ? 'In' : 'Out';
    bool isCashYouOwe = party.cashBalance < 0;

    String totalGoldDue = '${party.goldBalanceGrams.abs().toStringAsFixed(3)} g';
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
}
