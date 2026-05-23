import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swastik_mobile_app/core/utils/responsive_utils.dart';
import 'package:swastik_mobile_app/core/widgets/restricted_feature_card.dart';
import 'package:swastik_mobile_app/features/auth/providers/auth_providers.dart';
import 'package:swastik_mobile_app/features/settings/presentation/widgets/avatar_widget.dart';
import 'package:swastik_mobile_app/features/settings/providers/profile_providers.dart';
import 'device_management_screen.dart';
import 'notification_settings_screen.dart';
import 'edit_profile_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTablet = AppResponsive.isTablet(context);
    final isStaff = ref.watch(isStaffProvider);
    final profile = ref.watch(activeProfileProvider);

    return Container(
      color: const Color(0xFFFAF6EE), // Consistent warm beige background
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
              SizedBox(height: isTablet ? 24 : 20),

              // ─── PROFILE CARD ────────────────────────────────────
              _buildProfileCard(
                profile.name,
                isStaff ? 'STAFF' : 'ADMIN',
                'Swastik Jewels',
                profile.gradientIndex,
                profile.iconIndex,
                isTablet,
              ),
              SizedBox(height: isTablet ? 28 : 24),

              // ─── SECTION: ACCOUNT ────────────────────────────────
              _sectionLabel('Account', isTablet),
              const SizedBox(height: 10),

              // Grouped settings options card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
                  border: Border.all(
                    color: const Color(0xFFE5DEC9).withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _buildSettingsTile(
                      icon: Icons.person_outline_rounded,
                      label: 'Edit Profile',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const EditProfileScreen(),
                          ),
                        );
                      },
                      isTablet: isTablet,
                      showDivider: true,
                    ),
                    RestrictedFeatureCard(
                      isStaff: isStaff,
                      lockAlignment: Alignment.centerRight,
                      lockPadding: EdgeInsets.only(right: isTablet ? 20 : 16),
                      child: _buildSettingsTile(
                        icon: Icons.devices_rounded,
                        label: 'Device Management',
                        isLocked: isStaff,
                        onTap: () {
                          if (!isStaff) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const DeviceManagementScreen(),
                              ),
                            );
                          }
                        },
                        isTablet: isTablet,
                        showDivider: true,
                      ),
                    ),
                    _buildSettingsTile(
                      icon: Icons.notifications_none_outlined,
                      label: 'Notifications',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const NotificationSettingsScreen(),
                          ),
                        );
                      },
                      isTablet: isTablet,
                      showDivider: false,
                    ),
                  ],
                ),
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
    String roleLabel,
    String businessName,
    int gradientIndex,
    int iconIndex,
    bool isTablet,
  ) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 24 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isTablet ? 24 : 20),
        border: Border.all(
          color: const Color(0xFFE5DEC9).withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFD4B13B).withValues(alpha: 0.4),
                width: 2,
              ),
            ),
            child: UserAvatar(
              name: fullName,
              gradientIndex: gradientIndex,
              iconIndex: iconIndex,
              size: isTablet ? 72 : 60,
              fontSize: isTablet ? 24 : 20,
              iconSize: isTablet ? 32 : 26,
            ),
          ),
          SizedBox(width: isTablet ? 20 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        fullName.isEmpty ? 'User' : fullName,
                        style: GoogleFonts.montserrat(
                          fontSize: isTablet ? 20 : 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E1E1E),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3D0),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFFD4B13B).withValues(alpha: 0.5),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        roleLabel,
                        style: GoogleFonts.montserrat(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF8A7311),
                        ),
                      ),
                    ),
                  ],
                ),
                if (businessName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    businessName,
                    style: GoogleFonts.montserrat(
                      fontSize: isTablet ? 14 : 13,
                      color: const Color(0xFF8A7311),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
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
    required bool showDivider,
    bool isLocked = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 20 : 16,
              vertical: isTablet ? 18 : 16,
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isTablet ? 10 : 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3D0),
                    borderRadius: BorderRadius.circular(10),
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
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E1E1E),
                    ),
                  ),
                ),
                if (isLocked)
                  SizedBox(width: isTablet ? 22 : 20)
                else
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.grey[400],
                    size: isTablet ? 22 : 20,
                  ),
              ],
            ),
          ),
          if (showDivider)
            Padding(
              padding: EdgeInsets.only(left: isTablet ? 66 : 58),
              child: const Divider(
                color: Color(0xFFFAF6EE),
                height: 1,
                thickness: 1.2,
              ),
            ),
        ],
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
      child: TextButton.icon(
        onPressed: () async {
          final success = await ref.read(authStateProvider.notifier).logout();
          if (!success && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Please connect to the internet to logout safely.',
                  style: GoogleFonts.montserrat(),
                ),
                backgroundColor: const Color(0xFFD32F2F),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        icon: const Icon(
          Icons.logout_rounded,
          color: Color(0xFFC62828),
          size: 20,
        ),
        label: Text(
          'Logout',
          style: GoogleFonts.montserrat(
            fontSize: isTablet ? 16 : 15,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFC62828),
          ),
        ),
        style: TextButton.styleFrom(
          backgroundColor: const Color(0xFFFFEBEE), // Premium soft red pastel background
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isTablet ? 18 : 14),
            side: BorderSide(
              color: const Color(0xFFFFCDD2).withValues(alpha: 0.5),
              width: 1,
            ),
          ),
        ),
      ),
    );
  }
}
