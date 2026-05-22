import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swastik_mobile_app/core/utils/responsive_utils.dart';
import 'package:swastik_mobile_app/features/auth/providers/auth_providers.dart';
import 'device_management_screen.dart';


class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTablet = AppResponsive.isTablet(context);

    return Container(
      color: isTablet ? const Color(0xFFFAF6EE) : const Color(0xFFFDFBF7),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 28.0 : 20.0,
            vertical: isTablet ? 22.0 : 20.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── HEADER ─────────────────────────────────────────
              Text(
                'Settings',
                style: GoogleFonts.montserrat(
                  fontSize: isTablet ? 26 : 24,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E1E1E),
                ),
              ),
              SizedBox(height: isTablet ? 28 : 24),

              // ─── PROFILE CARD ────────────────────────────────────
              _buildProfileCard(
                'Admin',
                'Swastik Jewels',
                'admin@swastikjewels.com',
                isTablet,
              ),
              SizedBox(height: isTablet ? 28 : 24),

              // ─── SECTION: ACCOUNT ────────────────────────────────
              _sectionLabel('Account', isTablet),
              SizedBox(height: isTablet ? 16 : 12),
              _buildSettingsTile(
                icon: Icons.person_outline_rounded,
                label: 'Edit Profile',
                onTap: () {},
                isTablet: isTablet,
              ),
              _buildSettingsTile(
                icon: Icons.devices_rounded,
                label: 'Device Management',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const DeviceManagementScreen(),
                    ),
                  );
                },
                isTablet: isTablet,
              ),
              _buildSettingsTile(
                icon: Icons.notifications_none_outlined,
                label: 'Notifications',
                onTap: () {},
                isTablet: isTablet,
              ),
              SizedBox(height: isTablet ? 24 : 20),

              // ─── SECTION: BUSINESS ───────────────────────────────
              _sectionLabel('Business', isTablet),
              SizedBox(height: isTablet ? 16 : 12),
              _buildSettingsTile(
                icon: Icons.store_outlined,
                label: 'Business Details',
                onTap: () {},
                isTablet: isTablet,
              ),
              _buildSettingsTile(
                icon: Icons.currency_rupee_outlined,
                label: 'Currency & Units',
                onTap: () {},
                isTablet: isTablet,
              ),
              SizedBox(height: isTablet ? 24 : 20),

              // ─── SECTION: SUPPORT ────────────────────────────────
              _sectionLabel('Support', isTablet),
              SizedBox(height: isTablet ? 16 : 12),
              _buildSettingsTile(
                icon: Icons.help_outline_rounded,
                label: 'Help & FAQ',
                onTap: () {},
                isTablet: isTablet,
              ),
              _buildSettingsTile(
                icon: Icons.privacy_tip_outlined,
                label: 'Privacy Policy',
                onTap: () {},
                isTablet: isTablet,
              ),
              SizedBox(height: isTablet ? 32 : 28),

              // ─── SIGN OUT BUTTON ─────────────────────────────────
              _buildSignOutButton(context, ref, isTablet),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(
    String fullName,
    String businessName,
    String contact,
    bool isTablet,
  ) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 24 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isTablet ? 24 : 20),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: isTablet ? 72 : 60,
            height: isTablet ? 72 : 60,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFD4B13B), Color(0xFF8A7311)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U',
              style: GoogleFonts.montserrat(
                fontSize: isTablet ? 28 : 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(width: isTablet ? 20 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName.isEmpty ? 'User' : fullName,
                  style: GoogleFonts.montserrat(
                    fontSize: isTablet ? 20 : 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E1E1E),
                  ),
                ),
                if (businessName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    businessName,
                    style: GoogleFonts.montserrat(
                      fontSize: isTablet ? 14 : 13,
                      color: const Color(0xFF8A7311),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  contact,
                  style: GoogleFonts.montserrat(
                    fontSize: isTablet ? 13 : 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.edit_outlined,
            color: Colors.grey[400],
            size: isTablet ? 22 : 20,
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label, bool isTablet) {
    return Text(
      label.toUpperCase(),
      style: GoogleFonts.montserrat(
        fontSize: isTablet ? 12 : 11,
        fontWeight: FontWeight.w700,
        color: Colors.grey[500],
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isTablet,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: isTablet ? 12 : 10),
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 18 : 16,
          vertical: isTablet ? 16 : 14,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(isTablet ? 18 : 14),
          border: Border.all(color: Colors.grey.withOpacity(0.12)),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isTablet ? 10 : 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3D0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF8A7311),
                size: isTablet ? 22 : 18,
              ),
            ),
            SizedBox(width: isTablet ? 16 : 14),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.montserrat(
                  fontSize: isTablet ? 16 : 15,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF1E1E1E),
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
              size: isTablet ? 22 : 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignOutButton(
    BuildContext context,
    WidgetRef ref,
    bool isTablet,
  ) {
    return SizedBox(
      width: double.infinity,
      height: isTablet ? 58 : 52,
      child: OutlinedButton.icon(
        onPressed: () {
          ref.read(authStateProvider.notifier).logout();
        },
        icon: Icon(
          Icons.logout_rounded,
          color: const Color(0xFFC62828),
          size: isTablet ? 22 : 20,
        ),
        label: Text(
          'Logout',
          style: GoogleFonts.montserrat(
            fontSize: isTablet ? 16 : 15,
            fontWeight: FontWeight.w600,
            color: const Color(0xFFC62828),
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFC62828)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isTablet ? 18 : 14),
          ),
        ),
      ),
    );
  }
}
