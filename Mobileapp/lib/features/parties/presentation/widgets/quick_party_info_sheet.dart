import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:swastik_mobile_app/core/models/party_model.dart';
import 'package:swastik_mobile_app/core/models/transaction_model.dart';
import 'package:swastik_mobile_app/features/parties/providers/party_providers.dart';
import 'package:swastik_mobile_app/core/utils/time_utils.dart';

class QuickPartyInfoSheet extends ConsumerStatefulWidget {
  final PartyModel party;
  final TransactionModel transaction;

  const QuickPartyInfoSheet({
    super.key,
    required this.party,
    required this.transaction,
  });

  @override
  ConsumerState<QuickPartyInfoSheet> createState() => _QuickPartyInfoSheetState();
}

class _QuickPartyInfoSheetState extends ConsumerState<QuickPartyInfoSheet> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.party.name);
    _phoneController = TextEditingController(text: widget.party.phone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final updatedParty = widget.party.copyWith(
      name: name,
      phone: _phoneController.text.trim(),
      updatedAt: TimeUtils.now,
    );

    try {
      await ref.read(partyServiceProvider).updateParty(updatedParty);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Details updated successfully'),
            backgroundColor: Color(0xFF01565B),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.transaction;
    
    // Formatting Audit Info
    final createdByName = t.createdBy?.isNotEmpty == true ? t.createdBy! : 'Admin';
    final createdDateStr = DateFormat('dd MMM yyyy, hh:mm a').format(t.createdAt);
    
    String? updatedByName;
    String? updatedDateStr;
    if (t.updatedBy != null && t.updatedBy!.isNotEmpty) {
      updatedByName = t.updatedBy;
      if (t.updatedAt != null) {
        updatedDateStr = DateFormat('dd MMM yyyy, hh:mm a').format(t.updatedAt!);
      }
    }

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFFAF6EE),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Transaction & Party Info',
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF01565B),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Audit History Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5DEC9)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, size: 18, color: Color(0xFF735C0F)),
                      const SizedBox(width: 8),
                      Text(
                        'Audit History',
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF735C0F),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildAuditRow('Created By', createdByName, createdDateStr),
                  if (updatedByName != null && updatedDateStr != null) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Divider(height: 1, color: Color(0xFFE5DEC9)),
                    ),
                    _buildAuditRow('Last Edited By', updatedByName, updatedDateStr),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Edit Party Details
            Text(
              'Edit Party Details',
              style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF01565B),
              ),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: 'Party Name',
              controller: _nameController,
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: 'Phone Number',
              controller: _phoneController,
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 24),
            
            // Save Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF01565B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        'Save Changes',
                        style: GoogleFonts.montserrat(
                          fontSize: 15,
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
  }

  Widget _buildAuditRow(String label, String name, String date) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                name,
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
        Text(
          date,
          style: GoogleFonts.montserrat(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.montserrat(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE5DEC9)),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: GoogleFonts.montserrat(fontSize: 15),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: Colors.grey[500], size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}
