import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:swastik_mobile_app/core/utils/formatters.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swastik_mobile_app/core/utils/responsive_utils.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:swastik_mobile_app/features/auth/providers/auth_providers.dart';
import '../../providers/party_providers.dart';

class QuickAddPartyBottomSheet extends ConsumerStatefulWidget {
  final String? initialName;
  const QuickAddPartyBottomSheet({super.key, this.initialName});

  @override
  ConsumerState<QuickAddPartyBottomSheet> createState() => _QuickAddPartyBottomSheetState();
}

class _QuickAddPartyBottomSheetState extends ConsumerState<QuickAddPartyBottomSheet> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialName != null) {
      _nameController.text = widget.initialName!.toUpperCase();
    }
  }

  // Contact sync state variables
  final _contactSearchController = TextEditingController();
  final _addressFocusNode = FocusNode();
  List<Contact> _allContacts = [];
  List<Contact> _filteredContacts = [];
  bool _isLoadingContacts = false;
  bool _hasContactPermission = false;
  bool _permissionChecked = false;
  bool _isSyncing = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _contactSearchController.dispose();
    _addressFocusNode.dispose();
    super.dispose();
  }

  Future<void> _checkAndRequestPermission({bool forceSync = false}) async {
    if (_isSyncing) return;

    setState(() {
      _isLoadingContacts = true;
      if (forceSync) _isSyncing = true;
    });

    try {
      final status = await ph.Permission.contacts.status;
      if (status.isGranted && !forceSync) {
        setState(() {
          _hasContactPermission = true;
          _permissionChecked = true;
        });
        await _fetchContacts();
      } else {
        final result = await ph.Permission.contacts.request();
        setState(() {
          _hasContactPermission = result.isGranted;
          _permissionChecked = true;
        });
        if (result.isGranted) {
          await _fetchContacts();
        } else {
          setState(() {
            _isLoadingContacts = false;
            _isSyncing = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking contact permission: $e');
      setState(() {
        _isLoadingContacts = false;
        _isSyncing = false;
      });
    }
  }

  Future<void> _fetchContacts() async {
    try {
      final contacts = await FlutterContacts.getAll(properties: {ContactProperty.name, ContactProperty.phone});
      setState(() {
        _allContacts = contacts;
        _isLoadingContacts = false;
        _isSyncing = false;
      });
      if (_contactSearchController.text.isNotEmpty) {
        _filterContacts(_contactSearchController.text);
      }
    } catch (e) {
      debugPrint('Error fetching contacts: $e');
      setState(() {
        _isLoadingContacts = false;
        _isSyncing = false;
      });
    }
  }

  void _filterContacts(String query) {
    final search = query.toLowerCase().trim();
    if (search.isEmpty) {
      setState(() {
        _filteredContacts = [];
      });
      return;
    }

    setState(() {
      _filteredContacts = _allContacts.where((contact) {
        final name = (contact.displayName ?? '').toLowerCase();
        final matchesName = name.contains(search);

        final matchesPhone = contact.phones.any((phone) {
          final cleanNum = phone.number.replaceAll(RegExp(r'\D'), '');
          return cleanNum.contains(search);
        });

        return matchesName || matchesPhone;
      }).toList();
    });
  }

  void _selectContact(Contact contact) {
    setState(() {
      _nameController.text = contact.displayName ?? '';
      if (contact.phones.isNotEmpty) {
        String phoneStr = contact.phones.first.number;
        String cleanPhone = phoneStr.replaceAll(RegExp(r'\D'), '');
        if (cleanPhone.length > 10) {
          cleanPhone = cleanPhone.substring(cleanPhone.length - 10);
        }
        _phoneController.text = cleanPhone;
      } else {
        _phoneController.text = '';
      }
      _contactSearchController.clear();
      _filteredContacts = [];
    });

    FocusScope.of(context).requestFocus(_addressFocusNode);
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = AppResponsive.isTablet(context);
    final isStaff = ref.watch(isStaffProvider);
    final isAdmin = !isStaff;
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
            if (isAdmin) ...[
              _buildContactSearchField(),
              const SizedBox(height: 16),
            ],
            _buildTextField(
              label: 'Full Name *',
              hint: 'e.g. RAMESH JEWELLERS',
              prefixIcon: Icons.person_outline,
              controller: _nameController,
              inputFormatters: [UpperCaseTextFormatter()],
            ),
            const SizedBox(height: 16),
            _buildPhoneField(controller: _phoneController),
            const SizedBox(height: 16),
            _buildTextField(
              label: 'Address',
              hint: 'Complete billing/shipping address',
              maxLines: 3,
              controller: _addressController,
              focusNode: _addressFocusNode,
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
    FocusNode? focusNode,
    List<TextInputFormatter>? inputFormatters,
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
            focusNode: focusNode,
            inputFormatters: inputFormatters,
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

  Widget _buildContactSearchField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Search Phone Contacts',
          style: GoogleFonts.montserrat(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.grey[800],
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
            controller: _contactSearchController,
            onTap: () {
              if (!_permissionChecked) {
                _checkAndRequestPermission();
              }
            },
            onChanged: (val) {
              if (!_permissionChecked) {
                _checkAndRequestPermission();
              } else {
                _filterContacts(val);
              }
            },
            decoration: InputDecoration(
              hintText: 'Search contacts by name or number...',
              hintStyle: GoogleFonts.montserrat(color: Colors.grey[400]),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
              suffixIcon: _isLoadingContacts
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: Padding(
                        padding: EdgeInsets.all(12.0),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF755E0B),
                        ),
                      ),
                    )
                  : IconButton(
                      icon: Icon(
                        _permissionChecked && _hasContactPermission
                            ? Icons.sync
                            : Icons.lock_outline,
                        color: const Color(0xFF755E0B),
                        size: 20,
                      ),
                      onPressed: () {
                        _checkAndRequestPermission(forceSync: true);
                      },
                      tooltip: 'Sync Device Contacts',
                    ),
            ),
            style: GoogleFonts.montserrat(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (_permissionChecked && !_hasContactPermission) ...[
          const SizedBox(height: 4),
          Text(
            'Contact permission is denied. Tap sync icon to request permission.',
            style: GoogleFonts.montserrat(
              fontSize: 11,
              color: Colors.red[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        if (_filteredContacts.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 180),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE0D8C3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _filteredContacts.length,
              separatorBuilder: (context, index) => const Divider(
                height: 1,
                color: Color(0xFFFAF6EE),
              ),
              itemBuilder: (context, index) {
                final contact = _filteredContacts[index];
                final phone = contact.phones.isNotEmpty
                    ? contact.phones.first.number
                    : 'No phone number';
                return ListTile(
                  dense: true,
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFAF6EE),
                    child: Icon(Icons.person, color: Color(0xFF755E0B), size: 18),
                  ),
                  title: Text(
                    contact.displayName ?? '',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  subtitle: Text(
                    phone,
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                  onTap: () => _selectContact(contact),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
