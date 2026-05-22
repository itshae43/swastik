import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swastik_mobile_app/features/auth/models/user_profile.dart';
import 'package:swastik_mobile_app/features/auth/providers/auth_providers.dart';
import 'package:swastik_mobile_app/features/auth/providers/user_profiles_provider.dart';

class DeviceVerificationScreen extends ConsumerStatefulWidget {
  const DeviceVerificationScreen({super.key});

  @override
  ConsumerState<DeviceVerificationScreen> createState() =>
      _DeviceVerificationScreenState();
}

class _DeviceVerificationScreenState
    extends ConsumerState<DeviceVerificationScreen> {
  bool _isAdminTab = true;
  UserProfileModel? _selectedProfile;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final profilesState = ref.watch(userProfilesNotifierProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 16),
                  _buildLogo(),
                  const SizedBox(height: 24),
                  Text(
                    "Let's Get Started!",
                    style: GoogleFonts.montserrat(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E1E1E),
                    ),
                  ),
                  const SizedBox(height: 28),
                  _buildTabBar(),
                  const SizedBox(height: 32),
                  if (_isAdminTab)
                    _buildAdminView(authState)
                  else if (_selectedProfile != null)
                    _buildRequestAccessView(_selectedProfile!, profilesState)
                  else
                    _buildStaffView(profilesState),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── LOGO ─────────────────────────────────────────────────────────────────
  Widget _buildLogo() {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFD4B13B), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4B13B).withOpacity(0.12),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Image.asset(
            'assets/images/logo.png',
            width: 52,
            height: 52,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.diamond_outlined,
              color: Color(0xFFD4B13B),
              size: 40,
            ),
          ),
        ),
      ),
    );
  }

  // ─── TAB TOGGLE BAR ────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFFF4EDE4),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              label: 'Admin',
              icon: Icons.lock_person_outlined,
              isActive: _isAdminTab,
              onTap: () {
                setState(() {
                  _isAdminTab = true;
                  _selectedProfile = null;
                });
              },
            ),
          ),
          Expanded(
            child: _buildTabButton(
              label: 'Staff',
              icon: Icons.person_outline_rounded,
              isActive: !_isAdminTab,
              onTap: () {
                setState(() {
                  _isAdminTab = false;
                  _selectedProfile = null;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive ? const Color(0xFF8B6C1C) : Colors.grey[600],
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.montserrat(
                fontSize: 15,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? const Color(0xFF8B6C1C) : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── ADMIN TAB VIEW ────────────────────────────────────────────────────────
  Widget _buildAdminView(AuthStatus authState) {
    final isLoading = authState == AuthStatus.loading;

    return Column(
      children: [
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: isLoading
                ? null
                : () {
                    ref.read(authStateProvider.notifier).verify();
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E4620),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              elevation: 2,
            ),
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Text(
                    'Click to Verify',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        if (authState == AuthStatus.unverified ||
            authState == AuthStatus.error) ...[
          const SizedBox(height: 36),
          Text(
            'Unauthorized Device',
            style: GoogleFonts.montserrat(
              color: const Color(0xFFD32F2F),
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  // ─── STAFF TAB VIEW ────────────────────────────────────────────────────────
  Widget _buildStaffView(UserProfilesState profilesState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Staff Profile to Send Login Request to Admin',
          style: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 20),
        if (profilesState.isLoading && profilesState.profiles.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Color(0xFFD4B13B)),
              ),
            ),
          )
        else ...[
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: profilesState.profiles.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final profile = profilesState.profiles[index];
              return _buildProfileItem(profile);
            },
          ),
          const SizedBox(height: 24),
          _buildAddProfileButton(),
        ],
      ],
    );
  }

  Widget _buildProfileItem(UserProfileModel profile) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            setState(() {
              _selectedProfile = profile;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    profile.name,
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2C2C2C),
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey[400],
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddProfileButton() {
    return GestureDetector(
      onTap: _showAddProfileDialog,
      child: CustomPaint(
        painter: DashedRectPainter(
          color: const Color(0xFFD4B13B),
          strokeWidth: 1.5,
          radius: 16,
        ),
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.person_add_alt_1_outlined,
                color: Color(0xFFD4B13B),
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                'Add New Staff Profile',
                style: GoogleFonts.montserrat(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFD4B13B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── ADD PROFILE MODAL DIALOG ──────────────────────────────────────────────
  void _showAddProfileDialog() {
    final nameController = TextEditingController();
    final mobileController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xFFFFF8F0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Staff Profile',
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E1E1E),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: nameController,
                      style: GoogleFonts.montserrat(fontSize: 15),
                      decoration: _inputDecoration(
                        hint: 'Staff Name',
                        prefixIcon: Icons.person_outline_rounded,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: mobileController,
                      keyboardType: TextInputType.phone,
                      style: GoogleFonts.montserrat(fontSize: 15),
                      decoration: _inputDecoration(
                        hint: 'Mobile Number',
                        prefixIcon: Icons.phone_outlined,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Mobile number is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.montserrat(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Consumer(
                          builder: (context, ref, _) {
                            return ElevatedButton(
                              onPressed: () async {
                                if (formKey.currentState!.validate()) {
                                  final success = await ref
                                      .read(userProfilesNotifierProvider.notifier)
                                      .addProfile(
                                        nameController.text.trim(),
                                        mobileController.text.trim(),
                                      );
                                  if (success && context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Profile added successfully!',
                                          style: GoogleFonts.montserrat(),
                                        ),
                                        backgroundColor: const Color(0xFF1E4620),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  } else if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Failed to add profile.',
                                          style: GoogleFonts.montserrat(),
                                        ),
                                        backgroundColor: const Color(0xFFD32F2F),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E4620),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Add',
                                style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData prefixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.montserrat(color: Colors.grey[400], fontSize: 14),
      prefixIcon: Icon(prefixIcon, color: Colors.grey[500], size: 20),
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey[200]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD4B13B), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD32F2F)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD32F2F)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  // ─── REQUEST ACCESS DETAIL VIEW ──────────────────────────────────────────
  Widget _buildRequestAccessView(
    UserProfileModel profile,
    UserProfilesState profilesState,
  ) {
    // Find latest model state of this profile from userProfilesProvider
    final currentProfile = profilesState.profiles.firstWhere(
      (p) => p.id == profile.id,
      orElse: () => profile,
    );

    final isPending = currentProfile.status == 'pending_approval' ||
        currentProfile.requestPending;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _selectedProfile = null;
            });
          },
          child: Row(
            children: [
              Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.grey[600], size: 16),
              const SizedBox(width: 8),
              Text(
                'Back to Profiles',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3D0),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: Color(0xFFD4B13B),
                  size: 32,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                currentProfile.name,
                style: GoogleFonts.montserrat(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E1E1E),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                currentProfile.mobile,
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isPending
                      ? const Color(0xFFFFF3D0)
                      : const Color(0xFFECEFF1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isPending ? 'Status: Pending Approval' : 'Status: Inactive',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isPending
                        ? const Color(0xFF8B6C1C)
                        : Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        if (isPending)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFC8E6C9)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  color: Color(0xFF2E7D32),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Access request sent! Please wait for Admin approval to login.',
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF2E7D32),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: profilesState.isLoading
                  ? null
                  : () async {
                      final success = await ref
                          .read(userProfilesNotifierProvider.notifier)
                          .sendAccessRequest(currentProfile.id);
                      if (success && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Request sent to Admin!',
                              style: GoogleFonts.montserrat(),
                            ),
                            backgroundColor: const Color(0xFF1E4620),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      } else if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Failed to send request.',
                              style: GoogleFonts.montserrat(),
                            ),
                            backgroundColor: const Color(0xFFD32F2F),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E4620),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                elevation: 2,
              ),
              child: profilesState.isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Text(
                      'Send Request to Access',
                      style: GoogleFonts.montserrat(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
      ],
    );
  }
}

// ─── DASHED RECTANGLE CUSTOM PAINTER ──────────────────────────────────────────
class DashedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final double dash;
  final double radius;

  DashedRectPainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.gap = 4.0,
    this.dash = 6.0,
    this.radius = 16.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(radius),
      ));

    final dashPath = Path();
    double distance = 0.0;
    bool isDash = true;

    for (final pathMetric in path.computeMetrics()) {
      while (distance < pathMetric.length) {
        final len = isDash ? dash : gap;
        dashPath.addPath(
          pathMetric.extractPath(distance, distance + len),
          Offset.zero,
        );
        distance += len;
        isDash = !isDash;
      }
      distance = 0.0;
      isDash = true;
    }

    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
