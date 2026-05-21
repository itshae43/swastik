import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:swastik_mobile_app/core/utils/responsive_utils.dart';
import '../../providers/party_providers.dart';

class AddPartyScreen extends ConsumerStatefulWidget {
  const AddPartyScreen({super.key});

  @override
  ConsumerState<AddPartyScreen> createState() => _AddPartyScreenState();
}

class _AddPartyScreenState extends ConsumerState<AddPartyScreen> {
  String _transactionType = 'IN';
  String _category = 'Money';
  String _paymentMode = 'Cash'; // Cash, UPI, RTGS
  bool _isSaved = false;

  // Controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _amountController = TextEditingController();
  final _goldPurityController = TextEditingController();
  final _goldWeightController = TextEditingController();
  final _diamondCaratController = TextEditingController();
  final _diamondPiecesController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _amountController.dispose();
    _goldPurityController.dispose();
    _goldWeightController.dispose();
    _diamondCaratController.dispose();
    _diamondPiecesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = AppResponsive.isTablet(context);
    return Scaffold(
      backgroundColor: isTablet ? const Color(0xFFFAF6EE) : const Color(0xFFFDFBF7),
      appBar: AppBar(
        backgroundColor: isTablet ? const Color(0xFFFAF6EE) : const Color(0xFFFDFBF7),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF6B5800)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Add New Party',
          style: GoogleFonts.montserrat(
            color: const Color(0xFF6B5800),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: isTablet ? 720 : double.infinity,
            ),
            child: Column(
              children: [
            // Form
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                              selectedColor: const Color(0xFF8A7311),
                              isSelected: _transactionType == 'IN',
                              onTap: () => setState(() => _transactionType = 'IN'),
                            ),
                          ),
                          Expanded(
                            child: _buildTransactionTypeButton(
                              title: 'OUT (Give)',
                              icon: Icons.arrow_upward,
                              selectedColor: Colors.black87,
                              isSelected: _transactionType == 'OUT',
                              onTap: () => setState(() => _transactionType = 'OUT'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(color: Colors.grey.withOpacity(0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTextField(
                            label: 'Full Name *',
                            hint: 'e.g. Ramesh Jewellers',
                            prefixIcon: Icons.person_outline,
                            controller: _nameController,
                          ),
                          const SizedBox(height: 16),
                          _buildPhoneField(controller: _phoneController),
                          const SizedBox(height: 16),
                          _buildTextField(
                            label: 'Address',
                            hint: 'Complete billing/shipping address',
                            maxLines: 3,
                            controller: _addressController,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Category Toggle
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Category',
                        style: GoogleFonts.montserrat(
                          fontSize: 13, 
                          fontWeight: FontWeight.w600, 
                          color: Colors.black87
                        ),
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
                    const SizedBox(height: 24),

                    // Dynamic Fields based on Category
                    if (_category == 'Money') ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Payment Mode
                            Text(
                              'Payment Mode',
                              style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _buildPaymentModeChip('Cash'),
                                const SizedBox(width: 12),
                                _buildPaymentModeChip('UPI'),
                                const SizedBox(width: 12),
                                _buildPaymentModeChip('RTGS'),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Amount
                            Text(
                              'Amount',
                              style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _amountController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                _IndianCurrencyFormatter(),
                              ],
                              style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                              decoration: InputDecoration(
                                hintText: '0',
                                hintStyle: GoogleFonts.montserrat(color: Colors.grey.shade300, fontSize: 20, fontWeight: FontWeight.bold),
                                prefixIcon: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF4EDE4),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text('₹', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF8A7311))),
                                  ),
                                ),
                                prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                                  borderSide: const BorderSide(color: Color(0xFF8A7311)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (_category == 'Gold') ...[
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Purity %',
                                  style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _goldPurityController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  textAlign: TextAlign.right,
                                  style: GoogleFonts.montserrat(fontSize: 16, color: Colors.black87),
                                  decoration: InputDecoration(
                                    hintText: '99.5',
                                    hintStyle: GoogleFonts.montserrat(color: Colors.grey.shade400, fontSize: 16),
                                    suffixIcon: Padding(
                                      padding: const EdgeInsets.only(right: 16.0),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text('%', style: GoogleFonts.montserrat(fontSize: 18, color: Colors.grey.shade600)),
                                        ],
                                      ),
                                    ),
                                    suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
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
                                      borderSide: BorderSide(color: Colors.grey.shade400),
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
                                  style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _goldWeightController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  textAlign: TextAlign.right,
                                  style: GoogleFonts.montserrat(fontSize: 16, color: Colors.black87),
                                  decoration: InputDecoration(
                                    hintText: '0.00',
                                    hintStyle: GoogleFonts.montserrat(color: Colors.grey.shade400, fontSize: 16),
                                    suffixIcon: Padding(
                                      padding: const EdgeInsets.only(right: 16.0),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text('g', style: GoogleFonts.montserrat(fontSize: 18, color: Colors.grey.shade600)),
                                        ],
                                      ),
                                    ),
                                    suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
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
                                      borderSide: BorderSide(color: Colors.grey.shade400),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],

                    if (_category == 'Diamond') ...[
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'CARAT (CT)',
                                  style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _diamondCaratController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
                                  decoration: InputDecoration(
                                    hintText: '0.00',
                                    hintStyle: GoogleFonts.montserrat(color: Colors.grey.shade400, fontSize: 18, fontWeight: FontWeight.w600),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
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
                                      borderSide: BorderSide(color: Colors.grey.shade400),
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
                                  style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _diamondPiecesController,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
                                  decoration: InputDecoration(
                                    hintText: '0',
                                    hintStyle: GoogleFonts.montserrat(color: Colors.grey.shade400, fontSize: 18, fontWeight: FontWeight.w600),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
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
                                      borderSide: BorderSide(color: Colors.grey.shade400),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            // Save Button
            Container(
              padding: const EdgeInsets.all(16.0),
              color: isTablet ? const Color(0xFFFAF6EE) : const Color(0xFFFDFBF7),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: Consumer(
                  builder: (context, ref, child) {
                    final partyState = ref.watch(partyNotifierProvider);
                    
                    return ElevatedButton.icon(
                      onPressed: (partyState.isLoading || _isSaved) ? null : () async {
                        if (_nameController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter party name')),
                          );
                          return;
                        }
                        
                        if (_phoneController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter phone number')),
                          );
                          return;
                        }

                        // Parse the formatted cash amount
                        String cleanAmount = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
                        double cashValue = double.tryParse(cleanAmount) ?? 0.0;
                        
                        // Parse other values
                        double goldValue = double.tryParse(_goldWeightController.text) ?? 0.0;
                        double diamondValue = double.tryParse(_diamondCaratController.text) ?? 0.0;

                        // Apply sign based on transaction type (IN = Dr/Positive, OUT = Cr/Negative)
                        final double cash = _transactionType == 'IN' ? cashValue : -cashValue;
                        final double gold = _transactionType == 'IN' ? goldValue : -goldValue;
                        final double diamond = _transactionType == 'IN' ? diamondValue : -diamondValue;

                        final newPartyId = await ref.read(partyNotifierProvider.notifier).createParty(
                          name: _nameController.text.trim(),
                          type: _transactionType == 'IN' ? 'Customer' : 'Vendor',
                          phone: _phoneController.text.trim(),
                          address: _addressController.text.trim(),
                          email: '', 
                          cashBalance: cash,
                          goldBalance: gold,
                          diamondBalance: diamond,
                        );

                        if (newPartyId != null && mounted) {
                          setState(() => _isSaved = true);
                          await Future.delayed(const Duration(milliseconds: 800));
                          if (mounted) {
                            Navigator.pop(context, newPartyId);
                          }
                        } else if (partyState.error != null && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(partyState.error!)),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isSaved ? Colors.green : const Color(0xFF755E0B),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (Widget child, Animation<double> animation) {
                          return ScaleTransition(scale: animation, child: child);
                        },
                        child: _isSaved 
                          ? const Icon(Icons.check_circle, color: Colors.white, size: 20, key: ValueKey('check'))
                          : (partyState.isLoading 
                              ? const SizedBox(
                                  key: ValueKey('loading'),
                                  width: 20, 
                                  height: 20, 
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                                )
                              : const Icon(Icons.save, color: Colors.white, size: 20, key: ValueKey('save'))),
                      ),
                      label: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          _isSaved ? 'Saved!' : (partyState.isLoading ? 'Saving...' : 'Save Party'),
                          key: ValueKey(_isSaved ? 'saved_text' : (partyState.isLoading ? 'saving_text' : 'save_text')),
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
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
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? selectedColor : Colors.black54, size: 18),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.montserrat(
                color: isSelected ? selectedColor : Colors.black54,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryButton(String category) {
    final isSelected = _category == category;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _category = category),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              category,
              style: GoogleFonts.montserrat(
                color: isSelected ? const Color(0xFF8A7311) : Colors.black54,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 14,
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFDF9EE) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFFDCAE3D) : Colors.grey.shade300,
          ),
        ),
        child: Text(
          mode,
          style: GoogleFonts.montserrat(
            color: isSelected ? const Color(0xFF8A7311) : Colors.black87,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
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
    } else if (label.contains('(Optional)')) {
      final parts = label.split('(Optional)');
      labelSpans.add(TextSpan(text: parts[0]));
      labelSpans.add(TextSpan(text: '(Optional)', style: GoogleFonts.montserrat(color: Colors.grey[500], fontWeight: FontWeight.w600)));
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

  Widget _buildPhoneField({TextEditingController? controller}) {
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
              TextSpan(text: '*', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE0D8C3)),
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
}

class _IndianCurrencyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
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
