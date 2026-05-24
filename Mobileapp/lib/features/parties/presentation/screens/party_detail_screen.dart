import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swastik_mobile_app/core/models/transaction_model.dart';
import 'package:swastik_mobile_app/core/models/party_model.dart';
import 'package:swastik_mobile_app/features/ledger/providers/transaction_providers.dart';
import 'package:swastik_mobile_app/features/parties/providers/party_providers.dart';
import 'package:swastik_mobile_app/features/reminders/providers/reminder_providers.dart';
import 'package:swastik_mobile_app/core/models/reminder_model.dart';
import 'package:swastik_mobile_app/core/utils/communication_utils.dart';
import 'package:swastik_mobile_app/core/utils/responsive_utils.dart';
import 'package:swastik_mobile_app/core/utils/time_utils.dart';
import 'package:intl/intl.dart';

// ──────────────────────────── DATA MODELS ────────────────────────────

class PartyTransaction {
  final String title;
  final String subtitle; // e.g. "24 Oct 2023 • 10:30 AM"
  final String? notes; // Optional notes below date/time
  final String amount; // e.g. "- 50.000 g" or "+ ₹ 1,00,000"
  final String amountSubtitle; // e.g. "Gold (22K)" or "NEFT / RTGS"
  final Color amountColor;
  final String category; // "cash", "online", "metal"
  final IconData? icon;

  const PartyTransaction({
    required this.title,
    required this.subtitle,
    this.notes,
    required this.amount,
    required this.amountSubtitle,
    required this.amountColor,
    required this.category,
    this.icon,
  });
}

class PartyDetail {
  final String id;
  final String name;
  final String type; // e.g. "Wholesale Partner"
  final String location; // e.g. "Mumbai"
  final String initial;
  final String totalCashDue;
  final String cashDueLabel; // e.g. "Out" or "In"
  final bool isCashYouOwe; // true = Out (red arrow up), false = In (blue arrow down)
  final String totalGoldDue;
  final String goldDueLabel;
  final bool isGoldYouOwe;
  final String phone;
  final List<PartyTransaction> transactions;

  const PartyDetail({
    required this.id,
    required this.name,
    required this.type,
    required this.location,
    required this.initial,
    required this.totalCashDue,
    required this.cashDueLabel,
    required this.isCashYouOwe,
    required this.totalGoldDue,
    required this.goldDueLabel,
    required this.isGoldYouOwe,
    required this.phone,
    required this.transactions,
  });
}

// ──────────────────────────── SCREEN ────────────────────────────



class PartyDetailScreen extends ConsumerStatefulWidget {
  final PartyDetail party;

  const PartyDetailScreen({super.key, required this.party});

  @override
  ConsumerState<PartyDetailScreen> createState() => _PartyDetailScreenState();
}

class _PartyDetailScreenState extends ConsumerState<PartyDetailScreen> {
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Cash', 'UPI/RTGS', 'Gold', 'Diamond'];
  String _selectedTab = 'Transactions';
  String _selectedReminderTime = 'Tomorrow';
  final TextEditingController _reminderMsgController = TextEditingController();
  
  DateTime? _customDate;
  TimeOfDay? _customTime;
  bool _isSavingReminder = false;

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  void initState() {
    super.initState();
    // Start with empty text so the placeholder "Type your message..." shows.
  }

  @override
  void dispose() {
    _reminderMsgController.dispose();
    super.dispose();
  }

  List<TransactionModel> _getFilteredTransactions(List<TransactionModel> transactions) {
    if (_selectedFilter == 'All') return transactions;
    return transactions.where((t) {
      if (_selectedFilter == 'Cash') {
        return t.metalType.isEmpty && t.paymentMode == PaymentMode.cash;
      }
      if (_selectedFilter == 'UPI/RTGS') {
        return t.metalType.isEmpty && (t.paymentMode == PaymentMode.upi || t.paymentMode == PaymentMode.rtgs || t.paymentMode == PaymentMode.online);
      }
      if (_selectedFilter == 'Gold') {
        return t.metalType == 'gold';
      }
      if (_selectedFilter == 'Diamond') {
        return t.metalType == 'diamond';
      }
      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = AppResponsive.isTablet(context);
    final partiesAsync = ref.watch(partiesStreamProvider);
    final parties = partiesAsync.value ?? [];
    final partyModel = parties.firstWhere(
      (p) => p.id == widget.party.id,
      orElse: () => PartyModel(
        id: widget.party.id,
        name: widget.party.name,
        type: widget.party.type,
        phone: widget.party.phone,
        email: '',
        address: widget.party.location,
        cashBalance: 0.0,
        goldBalanceGrams: 0.0,
        silverBalanceGrams: 0.0,
        diamondBalanceCarats: 0.0,
        openingCashBalance: 0.0,
        openingGoldBalanceGrams: 0.0,
        openingDiamondBalanceCarats: 0.0,
        createdAt: TimeUtils.now,
        updatedAt: TimeUtils.now,
      ),
    );

    return Scaffold(
      backgroundColor: isTablet ? const Color(0xFFFAF6EE) : const Color(0xFFFDFBF7),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(partyModel),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    _buildDueSummaryCards(partyModel),
                    const SizedBox(height: 20),
                    _buildTabs(),
                    const SizedBox(height: 20),
                    if (_selectedTab == 'Transactions') ...[
                      _buildFilterTabs(),
                      const SizedBox(height: 16),
                      _buildTransactionList(),
                      const SizedBox(height: 24),
                      _buildOlderTransactionsLink(),
                    ] else ...[
                      _buildReminderTabContent(),
                    ],
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── APP BAR ─────────────────────────────────────────────────
  Widget _buildAppBar(PartyModel partyModel) {
    final liveLocation = partyModel.address.isNotEmpty 
        ? partyModel.address.split(',').last.trim() 
        : 'India';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Color(0xFF1E1E1E), size: 24),
            splashRadius: 24,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  partyModel.name,
                  style: GoogleFonts.montserrat(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E1E1E),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${partyModel.type} • $liveLocation${partyModel.phone.isNotEmpty ? ' • ${partyModel.phone}' : ''}',
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Printing statement...')),
              );
            },
            icon: const Icon(Icons.print_outlined, color: Color(0xFF1E1E1E), size: 24),
            splashRadius: 24,
          ),
          IconButton(
            onPressed: () {
              _showMoreOptions(context, partyModel);
            },
            icon: const Icon(Icons.more_vert, color: Color(0xFF1E1E1E), size: 24),
            splashRadius: 24,
          ),
        ],
      ),
    );
  }

  void _showMoreOptions(BuildContext context, PartyModel partyModel) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                _buildOptionTile(
                  Icons.edit_outlined,
                  'Edit Party Details',
                  onTap: () {
                    Navigator.pop(context);
                    _showEditPartyBottomSheet(context, partyModel);
                  },
                ),
                _buildOptionTile(Icons.file_download_outlined, 'Download Statement'),
                _buildOptionTile(Icons.share_outlined, 'Share Ledger'),
                _buildOptionTile(
                  Icons.delete_outline,
                  'Delete Party',
                  isDestructive: true,
                  onTap: () async {
                    Navigator.pop(context);
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('Delete Party', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
                        content: Text('Are you sure you want to delete ${partyModel.name}? This action cannot be undone.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text('Delete', style: TextStyle(color: Colors.red[700])),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true && mounted) {
                      try {
                        await ref.read(partyServiceProvider).deleteParty('', partyModel.id);
                        if (mounted) {
                          Navigator.pop(context); // Go back to ledger list
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Party deleted successfully')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to delete party: $e')),
                          );
                        }
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptionTile(IconData icon, String title, {bool isDestructive = false, VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? Colors.red[700] : const Color(0xFF4A3E1F),
      ),
      title: Text(
        title,
        style: GoogleFonts.montserrat(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: isDestructive ? Colors.red[700] : const Color(0xFF1E1E1E),
        ),
      ),
      onTap: onTap ?? () => Navigator.pop(context),
    );
  }

  void _showEditPartyBottomSheet(BuildContext context, PartyModel partyModel) {
    final nameController = TextEditingController(text: partyModel.name);
    final phoneController = TextEditingController(text: partyModel.phone);
    final addressController = TextEditingController(text: partyModel.address);
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isTablet = AppResponsive.isTablet(context);
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: BoxDecoration(
                color: isTablet ? const Color(0xFFFAF6EE) : const Color(0xFFFDFBF7),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Edit Party Details',
                          style: GoogleFonts.montserrat(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF4A3E1F),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildEditTextField(
                      label: 'Full Name *',
                      hint: 'e.g. Ramesh Jewellers',
                      prefixIcon: Icons.person_outline,
                      controller: nameController,
                    ),
                    const SizedBox(height: 16),
                    _buildEditPhoneField(controller: phoneController),
                    const SizedBox(height: 16),
                    _buildEditTextField(
                      label: 'Address',
                      hint: 'Complete billing/shipping address',
                      maxLines: 3,
                      controller: addressController,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: isSaving ? null : () async {
                          if (nameController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter party name')),
                            );
                            return;
                          }

                          setSheetState(() {
                            isSaving = true;
                          });

                          final updatedParty = partyModel.copyWith(
                            name: nameController.text.trim(),
                            phone: phoneController.text.trim(),
                            address: addressController.text.trim(),
                            updatedAt: TimeUtils.now,
                          );

                          final navigator = Navigator.of(context);
                          final scaffoldMessenger = ScaffoldMessenger.of(context);

                          try {
                            await ref.read(partyServiceProvider).updateParty(updatedParty);
                            navigator.pop();
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(
                                content: Text('Party details updated successfully'),
                                backgroundColor: Color(0xFF4A3E1F),
                              ),
                            );
                          } catch (e) {
                            setSheetState(() {
                              isSaving = false;
                            });
                            scaffoldMessenger.showSnackBar(
                              SnackBar(content: Text('Failed to update party details: $e')),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF755E0B),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        icon: isSaving 
                            ? const SizedBox(
                                width: 20, 
                                height: 20, 
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                              )
                            : const Icon(Icons.save, color: Colors.white, size: 20),
                        label: Text(
                          isSaving ? 'Saving...' : 'Save Changes',
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEditTextField({
    required String label,
    required String hint,
    IconData? prefixIcon,
    int maxLines = 1,
    TextEditingController? controller,
  }) {
    List<TextSpan> labelSpans = [];
    if (label.contains('*')) {
      final parts = label.split('*');
      labelSpans.add(TextSpan(text: parts[0]));
      labelSpans.add(const TextSpan(text: '*', style: TextStyle(color: Colors.red)));
    } else {
      labelSpans.add(TextSpan(text: label));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: GoogleFonts.montserrat(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.grey[800],
            ),
            children: labelSpans,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE0D8C3)),
            color: Colors.white,
          ),
          child: TextField(
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.montserrat(color: Colors.grey[400]),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              prefixIcon: prefixIcon != null
                  ? Icon(prefixIcon, color: Colors.grey[400])
                  : null,
            ),
            controller: controller,
            style: GoogleFonts.montserrat(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditPhoneField({TextEditingController? controller}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: GoogleFonts.montserrat(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.grey[800],
            ),
            children: const [
              TextSpan(text: 'Phone Number '),
              TextSpan(text: '(Optional)', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.normal)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE0D8C3)),
            color: Colors.white,
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                decoration: const BoxDecoration(
                  color: Color(0xFFF2EFE8),
                  borderRadius: BorderRadius.horizontal(left: Radius.circular(8)),
                ),
                alignment: Alignment.center,
                child: Text(
                  '+91',
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              Container(
                width: 1,
                color: const Color(0xFFE0D8C3),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: '10-digit number',
                    hintStyle: GoogleFonts.montserrat(color: Colors.grey[400]),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── DUE SUMMARY CARDS ──────────────────────────────────────
  Widget _buildDueSummaryCards(PartyModel partyModel) {
    final transactionsAsync = ref.watch(partyTransactionsStreamProvider(widget.party.id));
    final transactions = transactionsAsync.value ?? [];

    double cashBalance = partyModel.openingCashBalance;
    double onlineBalance = 0.0;
    double goldBalance = partyModel.openingGoldBalanceGrams;
    double diamondBalance = partyModel.openingDiamondBalanceCarats;

    for (final t in transactions) {
      final isDebit = t.type == TransactionType.payment ||
          t.type == TransactionType.sale ||
          t.type == TransactionType.metalOut;

      final isCredit = t.type == TransactionType.receipt ||
          t.type == TransactionType.purchase ||
          t.type == TransactionType.metalIn ||
          t.type == TransactionType.return_;

      if (t.metalType.isEmpty) {
        final val = t.cashAmount;
        if (t.paymentMode == PaymentMode.cash) {
          if (isCredit) cashBalance += val;
          if (isDebit) cashBalance -= val;
        } else {
          if (isCredit) onlineBalance += val;
          if (isDebit) onlineBalance -= val;
        }
      } else if (t.metalType == 'gold') {
        if (isCredit) goldBalance += t.metalWeight;
        if (isDebit) goldBalance -= t.metalWeight;
      } else if (t.metalType == 'diamond') {
        if (isCredit) diamondBalance += t.metalWeight;
        if (isDebit) diamondBalance -= t.metalWeight;
      }
    }

    // Self-healing check: if the stored balances in partyModel differ from the calculated ones,
    // we update the Firestore document so that other screens (like the Parties list) stay in sync.
    final calculatedTotalCash = cashBalance + onlineBalance;
    if ((partyModel.cashBalance - calculatedTotalCash).abs() > 0.01 ||
        (partyModel.goldBalanceGrams - goldBalance).abs() > 0.001 ||
        (partyModel.diamondBalanceCarats - diamondBalance).abs() > 0.01) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(partyServiceProvider).updateParty(
          partyModel.copyWith(
            cashBalance: calculatedTotalCash,
            goldBalanceGrams: goldBalance,
            diamondBalanceCarats: diamondBalance,
            updatedAt: TimeUtils.now,
          ),
        );
      });
    }

    final String displayCash = '${cashBalance > 0 ? '+ ' : (cashBalance < 0 ? '- ' : '')}₹${NumberFormat.decimalPattern('en_IN').format(cashBalance.abs().toStringAsFixed(0) == "0" ? 0 : cashBalance.abs())}';
    final String displayOnline = '${onlineBalance > 0 ? '+ ' : (onlineBalance < 0 ? '- ' : '')}₹${NumberFormat.decimalPattern('en_IN').format(onlineBalance.abs().toStringAsFixed(0) == "0" ? 0 : onlineBalance.abs())}';
    final String displayGold = '${goldBalance > 0 ? '+ ' : (goldBalance < 0 ? '- ' : '')}${goldBalance.abs() % 1 == 0 ? goldBalance.abs().toInt().toString() : goldBalance.abs().toStringAsFixed(3).replaceAll(RegExp(r"\.?0+$"), "")} g';
    final String displayDiamond = '${diamondBalance > 0 ? '+ ' : (diamondBalance < 0 ? '- ' : '')}${diamondBalance.abs() % 1 == 0 ? diamondBalance.abs().toInt().toString() : diamondBalance.abs().toStringAsFixed(2).replaceAll(RegExp(r"\.?0+$"), "")} ct';

    final isTablet = AppResponsive.isTablet(context);

    final cashCard = _buildDueCard(
      label: 'Total Cash',
      value: displayCash,
      statusLabel: cashBalance > 0 ? 'In' : (cashBalance < 0 ? 'Out' : 'Settled'),
      isYouOwe: cashBalance < 0,
      numericValue: cashBalance,
    );

    final onlineCard = _buildDueCard(
      label: 'Total UPI/RTGS',
      value: displayOnline,
      statusLabel: onlineBalance > 0 ? 'In' : (onlineBalance < 0 ? 'Out' : 'Settled'),
      isYouOwe: onlineBalance < 0,
      numericValue: onlineBalance,
    );

    final goldCard = _buildDueCard(
      label: 'Total Gold',
      value: displayGold,
      statusLabel: goldBalance > 0 ? 'In' : (goldBalance < 0 ? 'Out' : 'Settled'),
      isYouOwe: goldBalance < 0,
      numericValue: goldBalance,
    );

    final diamondCard = _buildDueCard(
      label: 'Total Diamond',
      value: displayDiamond,
      statusLabel: diamondBalance > 0 ? 'In' : (diamondBalance < 0 ? 'Out' : 'Settled'),
      isYouOwe: diamondBalance < 0,
      numericValue: diamondBalance,
    );

    if (isTablet) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(child: cashCard),
            const SizedBox(width: 12),
            Expanded(child: onlineCard),
            const SizedBox(width: 12),
            Expanded(child: goldCard),
            const SizedBox(width: 12),
            Expanded(child: diamondCard),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: cashCard),
              const SizedBox(width: 12),
              Expanded(child: onlineCard),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: goldCard),
              const SizedBox(width: 12),
              Expanded(child: diamondCard),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDueCard({
    required String label,
    required String value,
    required String statusLabel,
    required bool isYouOwe,
    required double numericValue,
  }) {
    final bool isSettled = numericValue.abs() < 0.0001; // Avoid double precision floating issues
    final statusColor = isSettled 
        ? Colors.grey[600]! 
        : (isYouOwe ? const Color(0xFFC62828) : const Color(0xFF2852C6));
    final arrowIcon = isSettled 
        ? Icons.done_all_rounded 
        : (isYouOwe ? Icons.north_east : Icons.south_west);
    final bgDecorColor = isSettled
        ? Colors.grey.withOpacity(0.04)
        : (isYouOwe
            ? const Color(0xFFC62828).withOpacity(0.06)
            : const Color(0xFF2852C6).withOpacity(0.06));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Decorative circle
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: bgDecorColor,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: GoogleFonts.montserrat(
                  fontSize: 18, // Slightly reduced to prevent overflow for ₹ currency symbol and long amounts
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(arrowIcon, size: 14, color: statusColor),
                  const SizedBox(width: 4),
                  Text(
                    statusLabel,
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── TABS ─────────────────────────────────────────
  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Transactions',
              isSelected: _selectedTab == 'Transactions',
              onTap: () => setState(() => _selectedTab = 'Transactions'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildTabButton(
              icon: Icons.notifications_none,
              label: 'Reminders',
              isSelected: _selectedTab == 'Reminders',
              onTap: () => setState(() => _selectedTab = 'Reminders'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final backgroundColor = isSelected ? const Color(0xFF4A3E1F) : const Color(0xFFF5EFE6);
    final textColor = isSelected ? Colors.white : const Color(0xFF4A3E1F);
    
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: textColor, size: 18),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── REMINDER TAB CONTENT ─────────────────────────────────────
  Widget _buildReminderTabContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Add Reminder Form
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE0D8CA)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF9F7F2),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.notifications_active_outlined,
                            size: 20, color: Color(0xFFD4AF37)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'New Reminder',
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E1E1E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Message Input
                      TextField(
                        controller: _reminderMsgController,
                        maxLines: null,
                        minLines: 3,
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
                          color: Colors.grey[800],
                          height: 1.5,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Type your message...',
                          filled: true,
                          fillColor: const Color(0xFFF9F7F2),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE0D8CA)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE0D8CA)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF4A3E1F)),
                          ),
                          contentPadding: const EdgeInsets.all(14),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'When',
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          'Tomorrow',
                          'In 2 days',
                          'Next Week',
                          'Custom Date',
                        ].map((time) {
                          final isSelected = _selectedReminderTime == time;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedReminderTime = time),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFD4AF37) : const Color(0xFFF5EFE6),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFFD4AF37) : const Color(0xFFE0D8CA),
                                ),
                              ),
                              child: Text(
                                time,
                                style: GoogleFonts.montserrat(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                  color: isSelected ? const Color(0xFF4A3E1F) : Colors.grey[700],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      if (_selectedReminderTime == 'Custom Date') ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Date',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  InkWell(
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: _customDate ?? TimeUtils.now,
                                        firstDate: DateTime(2000),
                                        lastDate: DateTime(2100),
                                        builder: (context, child) {
                                          return Theme(
                                            data: Theme.of(context).copyWith(
                                              colorScheme: const ColorScheme.light(
                                                primary: Color(0xFF4A3E1F),
                                                onPrimary: Colors.white,
                                                onSurface: Colors.black,
                                              ),
                                            ),
                                            child: child!,
                                          );
                                        },
                                      );
                                      if (picked != null) {
                                        setState(() => _customDate = picked);
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: const Color(0xFFD4AF37)),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.calendar_today_outlined, size: 18, color: Color(0xFF6B5800)),
                                          const SizedBox(width: 8),
                                          Text(
                                            _customDate != null ? _formatDate(_customDate!) : 'Select Date',
                                            style: GoogleFonts.montserrat(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: _customDate != null ? Colors.black87 : Colors.grey[500],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Time',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  InkWell(
                                    onTap: () async {
                                      final picked = await showTimePicker(
                                        context: context,
                                        initialTime: _customTime ?? TimeOfDay.now(),
                                        builder: (context, child) {
                                          return Theme(
                                            data: Theme.of(context).copyWith(
                                              colorScheme: const ColorScheme.light(
                                                primary: Color(0xFF4A3E1F),
                                                onPrimary: Colors.white,
                                                onSurface: Colors.black,
                                              ),
                                            ),
                                            child: child!,
                                          );
                                        },
                                      );
                                      if (picked != null) {
                                        setState(() => _customTime = picked);
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: const Color(0xFFE0D8CA)),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.access_time, size: 18, color: Color(0xFF6B5800)),
                                          const SizedBox(width: 8),
                                          Text(
                                            _customTime != null ? _customTime!.format(context) : 'Select Time',
                                            style: GoogleFonts.montserrat(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: _customTime != null ? Colors.black87 : Colors.grey[500],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 24),
                      Material(
                        color: const Color(0xFF4A3E1F),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _isSavingReminder
                              ? null
                              : () async {
                                  if (_reminderMsgController.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Please enter a reminder message')),
                                    );
                                    return;
                                  }

                                  DateTime reminderDate;
                                  if (_selectedReminderTime == 'Tomorrow') {
                                    reminderDate = TimeUtils.now.add(const Duration(days: 1));
                                  } else if (_selectedReminderTime == 'In 2 days') {
                                    reminderDate = TimeUtils.now.add(const Duration(days: 2));
                                  } else if (_selectedReminderTime == 'Next Week') {
                                    reminderDate = TimeUtils.now.add(const Duration(days: 7));
                                  } else {
                                    if (_customDate == null) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Please select a custom date')),
                                      );
                                      return;
                                    }
                                    reminderDate = DateTime(
                                      _customDate!.year,
                                      _customDate!.month,
                                      _customDate!.day,
                                      _customTime?.hour ?? 9,
                                      _customTime?.minute ?? 0,
                                    );
                                  }

                                  setState(() => _isSavingReminder = true);
                                  
                                  await ref.read(reminderNotifierProvider.notifier).createReminder(
                                    partyId: widget.party.id,
                                    partyName: widget.party.name,
                                    partyPhone: widget.party.phone,
                                    title: 'Reminder', // Default title
                                    note: _reminderMsgController.text.trim(),
                                    date: reminderDate,
                                  );

                                  if (mounted) {
                                    setState(() {
                                      _isSavingReminder = false;
                                      _reminderMsgController.clear();
                                      _customDate = null;
                                      _customTime = null;
                                      _selectedReminderTime = 'Tomorrow';
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Saved to Reminders',
                                          style: GoogleFonts.montserrat(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        backgroundColor: const Color(0xFF4A3E1F),
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    );
                                  }
                                },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_isSavingReminder)
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                else
                                  const Icon(Icons.bookmark_added_outlined, size: 18, color: Colors.white),
                                const SizedBox(width: 8),
                                Text(
                                  _isSavingReminder ? 'Saving...' : 'Save to Reminders',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
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
            ),
          ),
          const SizedBox(height: 32),
          // Previous Reminders Section
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 1,
                  color: const Color(0xFFE0D8CA),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'PREVIOUS REMINDERS',
                  style: GoogleFonts.montserrat(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[600],
                    letterSpacing: 1,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  height: 1,
                  color: const Color(0xFFE0D8CA),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Real reminder items
          Consumer(
            builder: (context, ref, child) {
              final remindersAsync = ref.watch(partyRemindersStreamProvider(widget.party.id));
              
              return remindersAsync.when(
                data: (reminders) {
                  if (reminders.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'No previous reminders',
                          style: GoogleFonts.montserrat(color: Colors.grey),
                        ),
                      ),
                    );
                  }
                  
                  // Sort: Newest created or imminent first as requested
                  final sorted = reminders.toList()
                    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

                  return Column(
                    children: sorted.map((r) => _buildPreviousReminderCard(r)).toList(),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPreviousReminderCard(ReminderModel reminder) {
    final isPending = reminder.status != ReminderStatus.completed;
    final statusText = isPending ? 'Pending' : 'Completed';
    final dateStr = DateFormat('dd MMM yyyy • hh:mm a').format(reminder.date);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0D8CA)),
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPending ? const Color(0xFFF5EFE6) : const Color(0xFFF9F7F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isPending ? const Color(0xFFE0D8CA) : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        if (isPending)
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF6B5800),
                              shape: BoxShape.circle,
                            ),
                          )
                        else
                          const Icon(Icons.check, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isPending ? const Color(0xFF6B5800) : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.phone_android, size: 12, color: Colors.grey[700]),
                        const SizedBox(width: 4),
                        Text(
                          reminder.partyPhone.isNotEmpty ? reminder.partyPhone : 'No Phone',
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.calendar_today_outlined, size: 12, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    dateStr,
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 18, color: Colors.grey[600]),
                onSelected: (value) {
                  if (value == 'delete') {
                    ref.read(reminderNotifierProvider.notifier).deleteReminder(reminder.id);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            reminder.title,
            style: GoogleFonts.montserrat(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E1E1E),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            reminder.note,
            style: GoogleFonts.montserrat(
              fontSize: 13,
              color: Colors.grey[700],
              height: 1.4,
            ),
          ),
          if (isPending) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                _buildActionIcon(
                  icon: Icons.call,
                  color: const Color(0xFF2E7D32),
                  onTap: () => CommunicationUtils.makeCall(widget.party.phone),
                  label: 'Call',
                ),
                const SizedBox(width: 12),
                _buildActionIcon(
                  icon: Icons.chat_outlined,
                  color: const Color(0xFF25D366),
                  onTap: () => CommunicationUtils.launchWhatsApp(widget.party.phone, reminder.note),
                  label: 'WA',
                ),
                const Spacer(),
                OutlinedButton(
                  onPressed: () {
                    _showEditReminderDialog(reminder);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                    side: const BorderSide(color: Color(0xFFE0D8CA)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: const Text('Edit'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    ref.read(reminderNotifierProvider.notifier).markAsDone(reminder.id);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A3E1F),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: const Icon(Icons.check, size: 18, color: Colors.white),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionIcon({required IconData icon, required Color color, required VoidCallback onTap, required String label}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.montserrat(
            fontSize: 8,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  void _showEditReminderDialog(ReminderModel reminder) {
    final noteController = TextEditingController(text: reminder.note);
    DateTime selectedDate = reminder.date;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Edit Reminder', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: noteController,
                decoration: const InputDecoration(labelText: 'Note'),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text('Date: ${DateFormat('dd MMM yyyy • hh:mm a').format(selectedDate)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: TimeUtils.now,
                    lastDate: TimeUtils.now.add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(selectedDate),
                    );
                    if (time != null) {
                      setState(() {
                        selectedDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                      });
                    }
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                ref.read(reminderNotifierProvider.notifier).updateReminder(
                  reminder.copyWith(note: noteController.text, date: selectedDate),
                );
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A3E1F)),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ─── FILTER TABS ────────────────────────────────────────────
  Widget _buildFilterTabs() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFE0D8CA), width: 1),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: _filters.map((filter) {
            final isSelected = _selectedFilter == filter;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedFilter = filter;
                });
              },
              child: Container(
                margin: const EdgeInsets.only(right: 24),
                padding: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? const Color(0xFF4A3E1F) : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                child: Text(
                  filter,
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? const Color(0xFF4A3E1F) : Colors.grey[500],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─── TRANSACTION LIST ───────────────────────────────────────
  Widget _buildTransactionList() {
    final transactionsAsync = ref.watch(partyTransactionsStreamProvider(widget.party.id));

    return transactionsAsync.when(
      data: (transactions) {
        final filteredTransactions = _getFilteredTransactions(transactions);

        if (filteredTransactions.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 60),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text(
                    'No transactions found',
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: filteredTransactions.map((txn) => _buildTransactionCard(txn)).toList(),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildTransactionCard(TransactionModel txn) {
    // Determine left border color based on category
    Color leftBorderColor;
    final cat = txn.metalType;
    if (cat == 'gold') {
      leftBorderColor = const Color(0xFFC7A22A);
    } else if (cat == 'diamond') {
      leftBorderColor = const Color(0xFF7E57C2);
    } else if (cat.isEmpty) {
      leftBorderColor = const Color(0xFF2852C6);
    } else {
      leftBorderColor = const Color(0xFF4A3E1F);
    }

    final isCredit = txn.type == TransactionType.receipt || txn.type == TransactionType.metalIn;
    final color = isCredit ? const Color(0xFF2852C6) : const Color(0xFFC62828);
    
    String amountStr = '';
    String amountSubtitle = '';
    if (txn.metalType.isEmpty) {
      amountStr = '₹ ${txn.cashAmount.toStringAsFixed(2)}';
      amountSubtitle = txn.paymentMode == PaymentMode.cash ? 'Cash' : 'UPI / RTGS';
    } else if (txn.metalType == 'gold') {
      amountStr = '${txn.metalWeight}g';
      amountSubtitle = txn.metalPurity.isNotEmpty ? 'Gold (${txn.metalPurity}%)' : 'Gold';
    } else if (txn.metalType == 'diamond') {
      amountStr = '${txn.metalWeight}ct';
      amountSubtitle = txn.metalPurity.isNotEmpty ? 'Diamond (${txn.metalPurity})' : 'Diamond';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.12)),
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
            // Left colored accent bar
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
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title row with amount
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    txn.typeLabel,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF1E1E1E),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('dd MMM yyyy • hh:mm a').format(txn.date),
                                style: GoogleFonts.montserrat(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              amountStr,
                              style: GoogleFonts.montserrat(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              amountSubtitle,
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: color.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (txn.notes.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9F7F2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          txn.notes,
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            color: Colors.grey[700],
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── OLDER TRANSACTIONS LINK ────────────────────────────────
  Widget _buildOlderTransactionsLink() {
    return Center(
      child: TextButton(
        onPressed: () {
          // Load older transactions
        },
        child: Text(
          'Older Transactions',
          style: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6B5800),
            decoration: TextDecoration.underline,
            decorationColor: const Color(0xFF6B5800),
          ),
        ),
      ),
    );
  }
}
