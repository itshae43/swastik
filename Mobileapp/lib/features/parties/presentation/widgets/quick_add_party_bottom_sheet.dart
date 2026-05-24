import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swastik_mobile_app/core/utils/responsive_utils.dart';
import '../../providers/party_providers.dart';

class QuickAddPartyBottomSheet extends ConsumerStatefulWidget {
  const QuickAddPartyBottomSheet({super.key});

  @override
  ConsumerState<QuickAddPartyBottomSheet> createState() => _QuickAddPartyBottomSheetState();
}

class _QuickAddPartyBottomSheetState extends ConsumerState<QuickAddPartyBottomSheet> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isSaved = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = AppResponsive.isTablet(context);
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
                  'Quick Add Customer',
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
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: Consumer(
                builder: (context, ref, child) {
                  final partyState = ref.watch(partyNotifierProvider);
                  
                  return ElevatedButton.icon(
                    onPressed: (partyState.isLoading || _isSaved) ? null : () async {
                      if (_nameController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter customer name')),
                        );
                        return;
                      }
                      
                      final navigator = Navigator.of(context);
                      final scaffoldMessenger = ScaffoldMessenger.of(context);

                      final newPartyId = await ref.read(partyNotifierProvider.notifier).createParty(
                        name: _nameController.text.trim(),
                        type: 'Customer',
                        phone: _phoneController.text.trim(),
                        address: _addressController.text.trim(),
                        email: '', 
                        cashBalance: 0.0,
                        goldBalance: 0.0,
                        diamondBalance: 0.0,
                      );

                      if (newPartyId != null) {
                        if (mounted) {
                          setState(() => _isSaved = true);
                        }
                        await Future.delayed(const Duration(milliseconds: 600));
                        navigator.pop(newPartyId);
                      } else if (partyState.error != null) {
                        scaffoldMessenger.showSnackBar(
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
                    icon: _isSaved 
                        ? const Icon(Icons.check_circle, color: Colors.white, size: 20)
                        : (partyState.isLoading 
                            ? const SizedBox(
                                width: 20, 
                                height: 20, 
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                              )
                            : const Icon(Icons.save, color: Colors.white, size: 20)),
                    label: Text(
                      _isSaved ? 'Saved!' : (partyState.isLoading ? 'Saving...' : 'Save Customer'),
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
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
}
