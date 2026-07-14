import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swastik_mobile_app/core/utils/responsive_utils.dart';
import 'package:swastik_mobile_app/features/auth/models/user_profile.dart';
import 'package:swastik_mobile_app/features/auth/providers/auth_providers.dart';
import 'package:swastik_mobile_app/features/auth/providers/user_profiles_provider.dart';
import 'package:swastik_mobile_app/core/utils/device_identity.dart';

class DeviceVerificationScreen extends ConsumerStatefulWidget {
  const DeviceVerificationScreen({super.key});

  @override
  ConsumerState<DeviceVerificationScreen> createState() =>
      _DeviceVerificationScreenState();
}

class _DeviceVerificationScreenState
    extends ConsumerState<DeviceVerificationScreen>
    with SingleTickerProviderStateMixin {
  bool _isAdminTab = true;
  UserProfileModel? _selectedProfile;
  late AnimationController _warningController;
  bool _showWarning = false;
  bool _isVerificationTriggeredByClick = false;

  // Timers and countdown for request access
  Timer? _countdownTimer;
  Timer? _pollingTimer;
  int _remainingSeconds = 300;

  void _startTimers(UserProfileModel profile) {
    _stopTimers();
    
    final requestedAt = profile.requestedAt;
    if (requestedAt != null) {
      final diff = DateTime.now().difference(requestedAt).inSeconds;
      _remainingSeconds = (300 - diff).clamp(0, 300);
    } else {
      _remainingSeconds = 300;
    }

    if (_remainingSeconds <= 0) {
      _handleRequestExpiry();
      return;
    }

    // Refresh UI with initial calculated remaining time
    if (mounted) {
      setState(() {});
    }

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
          } else {
            _stopTimers();
            _handleRequestExpiry();
          }
        });
      }
    });

    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (mounted && _selectedProfile != null) {
        await ref.read(userProfilesNotifierProvider.notifier).fetchProfiles();
        
        final state = ref.read(userProfilesNotifierProvider);
        final latestProfile = state.profiles.firstWhere(
          (p) => p.id == _selectedProfile!.id,
          orElse: () => _selectedProfile!,
        );
        if (latestProfile.status != 'pending_approval') {
          _stopTimers();
          if (mounted) {
            if (latestProfile.status == 'approved') {
              ref.read(authStateProvider.notifier).loginAsStaff(latestProfile);
            } else {
              setState(() {
                _selectedProfile = latestProfile;
              });
            }
          }
        }
      }
    });
  }

  void _stopTimers() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  void _handleRequestExpiry() {
    if (mounted) {
      setState(() {
        _selectedProfile = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Access request expired.',
            style: GoogleFonts.montserrat(),
          ),
          backgroundColor: const Color(0xFFD32F2F),
          behavior: SnackBarBehavior.floating,
        ),
      );
      ref.read(userProfilesNotifierProvider.notifier).fetchProfiles();
    }
  }

  @override
  void initState() {
    super.initState();
    _warningController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );
    _warningController.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        if (mounted) {
          setState(() {
            _showWarning = false;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _warningController.dispose();
    _stopTimers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final profilesState = ref.watch(userProfilesNotifierProvider);

    final isTablet = AppResponsive.isTablet(context);
    final double maxCardWidth = isTablet ? 600.0 : 480.0;
    final double logoSize = isTablet ? 140.0 : 116.0;
    final double innerLogoSize = isTablet ? 112.0 : 92.0;
    final double imageSize = isTablet ? 72.0 : 58.0;
    final double paddingHorizontal = isTablet ? 36.0 : 24.0;
    final double paddingVertical = isTablet ? 40.0 : 32.0;

    ref.listen<AuthStatus>(authStateProvider, (previous, next) {
      if (next == AuthStatus.unverified || next == AuthStatus.error) {
        if (mounted) {
          if (_isVerificationTriggeredByClick) {
            setState(() {
              _showWarning = true;
            });
            _warningController.reverse(from: 1.0);
            _isVerificationTriggeredByClick = false;
          }
        }
      } else if (next == AuthStatus.loading) {
        if (mounted) {
          setState(() {
            _showWarning = false;
          });
          _warningController.stop();
        }
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFFFDF9),
                    Color(0xFFFFF8F0),
                    Color(0xFFFFF0E0),
                  ],
                ),
              ),
            ),
          ),
          // Blurred background decoration blobs
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: isTablet ? 400 : 300,
              height: isTablet ? 400 : 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFD4B13B).withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            right: -100,
            child: Container(
              width: isTablet ? 450 : 350,
              height: isTablet ? 450 : 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1E4620).withValues(alpha: 0.04),
              ),
            ),
          ),
          // Scrollable content
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxCardWidth),
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: paddingHorizontal,
                    vertical: paddingVertical,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 16),
                      _buildLogo(logoSize, innerLogoSize, imageSize),
                      const SizedBox(height: 24),
                      Text(
                        "Let's Get Started!",
                        style: GoogleFonts.montserrat(
                          fontSize: isTablet ? 30 : 26,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E1E1E),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Verify your device or select your profile below",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.montserrat(
                          fontSize: isTablet ? 15 : 13,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 28),
                      _buildTabBar(isTablet),
                      const SizedBox(height: 32),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _isAdminTab
                            ? _buildAdminView(authState, isTablet)
                            : _selectedProfile != null
                                ? _buildRequestAccessView(
                                    _selectedProfile!,
                                    profilesState,
                                    isTablet,
                                  )
                                : _buildStaffView(profilesState, isTablet),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── LOGO ─────────────────────────────────────────────────────────────────
  Widget _buildLogo(double logoSize, double innerLogoSize, double imageSize) {
    return Container(
      width: logoSize,
      height: logoSize,
      decoration: BoxDecoration(
        color: Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFFD4B13B),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4B13B).withValues(alpha: 0.15),
            blurRadius: 24,
            spreadRadius: 4,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Container(
        width: innerLogoSize,
        height: innerLogoSize,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFFD4B13B),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Image.asset(
              'assets/images/logo.png',
              width: imageSize,
              height: imageSize,
              fit: BoxFit.contain,
              errorBuilder: (ctx, err, stack) => Icon(
                Icons.diamond_outlined,
                color: const Color(0xFFD4B13B),
                size: imageSize - 8,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── TAB TOGGLE BAR ────────────────────────────────────────────────────────
  Widget _buildTabBar(bool isTablet) {
    return Container(
      height: isTablet ? 64 : 56,
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
              isTablet: isTablet,
              onTap: () {
                setState(() {
                  _isAdminTab = true;
                  _selectedProfile = null;
                  _showWarning = false;
                  _isVerificationTriggeredByClick = false;
                });
                _warningController.stop();
              },
            ),
          ),
          Expanded(
            child: _buildTabButton(
              label: 'Staff',
              icon: Icons.person_outline_rounded,
              isActive: !_isAdminTab,
              isTablet: isTablet,
              onTap: () {
                setState(() {
                  _isAdminTab = false;
                  _selectedProfile = null;
                  _showWarning = false;
                  _isVerificationTriggeredByClick = false;
                });
                _warningController.stop();
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
    required bool isTablet,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isActive
              ? Border.all(color: const Color(0xFFD4B13B).withValues(alpha: 0.15), width: 1)
              : null,
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: const Color(0xFFD4B13B).withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
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
              size: isTablet ? 22 : 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.montserrat(
                fontSize: isTablet ? 16 : 15,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                color: isActive ? const Color(0xFF8B6C1C) : Colors.grey[600],
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── ADMIN TAB VIEW ────────────────────────────────────────────────────────
  Widget _buildAdminView(AuthStatus authState, bool isTablet) {
    final isLoading = authState == AuthStatus.loading;

    return Column(
      key: const ValueKey('AdminView'),
      children: [
        SizedBox(
          width: double.infinity,
          height: isTablet ? 64 : 56,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              gradient: LinearGradient(
                colors: isLoading
                    ? [const Color(0xFF7CA081), const Color(0xFF7CA081)]
                    : [const Color(0xFF2E6F40), const Color(0xFF1E4620)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E4620).withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () {
                      setState(() {
                        _isVerificationTriggeredByClick = true;
                      });
                      ref.read(authStateProvider.notifier).verify();
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                ),
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
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.verified_user_outlined, color: Colors.white, size: isTablet ? 22 : 20),
                        const SizedBox(width: 8),
                        Text(
                          'Click to Verify Device',
                          style: GoogleFonts.montserrat(
                            fontSize: isTablet ? 17 : 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        _buildWarningCard(isTablet),
      ],
    );
  }

  // ─── WARNING CARD ──────────────────────────────────────────────────────────
  Widget _buildWarningCard(bool isTablet) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: _showWarning
          ? AnimatedBuilder(
              animation: _warningController,
              builder: (context, child) {
                return Container(
                  margin: const EdgeInsets.only(top: 28),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFFFCDD2),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFC62828).withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(20, isTablet ? 20 : 18, 12, isTablet ? 20 : 18),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFCDD2),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFC62828).withValues(alpha: 0.15),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.gpp_bad_rounded,
                                color: const Color(0xFFC62828),
                                size: isTablet ? 26 : 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Unauthorized Device',
                                    style: GoogleFonts.montserrat(
                                      color: const Color(0xFFB71C1C),
                                      fontSize: isTablet ? 16 : 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'This device is not registered. Please contact your Admin.',
                                    style: GoogleFonts.montserrat(
                                      color: const Color(0xFF7F0000),
                                      fontSize: isTablet ? 14 : 13,
                                      fontWeight: FontWeight.w500,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _showWarning = false;
                                  _isVerificationTriggeredByClick = false;
                                });
                                _warningController.stop();
                              },
                              icon: Icon(
                                Icons.close_rounded,
                                color: const Color(0xFFB71C1C),
                                size: isTablet ? 22 : 20,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              splashRadius: 16,
                            ),
                          ],
                        ),
                      ),
                      LinearProgressIndicator(
                        value: _warningController.value,
                        backgroundColor: const Color(0xFFFFCDD2),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFFE53935),
                        ),
                        minHeight: 4.0,
                      ),
                    ],
                  ),
                );
              },
            )
          : const SizedBox.shrink(),
    );
  }

  // ─── STAFF TAB VIEW ────────────────────────────────────────────────────────
  Widget _buildStaffView(UserProfilesState profilesState, bool isTablet) {
    return Column(
      key: const ValueKey('StaffView'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (profilesState.isLoading && profilesState.profiles.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
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
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final profile = profilesState.profiles[index];
              return _buildProfileItem(profile, isTablet);
            },
          ),
          const SizedBox(height: 20),
          _buildAddProfileButton(isTablet),
        ],
      ],
    );
  }

  Widget _buildProfileItem(UserProfileModel profile, bool isTablet) {
    final bool isActive = profile.sessionActive;
    final bool isPending = profile.status == 'pending_approval' || profile.requestPending;

    Color badgeBgColor = const Color(0xFFECEFF1);
    Color badgeTextColor = const Color(0xFF546E7A);
    Color badgeDotColor = const Color(0xFF78909C);
    String statusText = 'Inactive';

    if (isActive) {
      badgeBgColor = const Color(0xFFE8F5E9);
      badgeTextColor = const Color(0xFF2E7D32);
      badgeDotColor = const Color(0xFF4CAF50);
      statusText = 'Active';
    } else if (isPending) {
      badgeBgColor = const Color(0xFFFFF3E0);
      badgeTextColor = const Color(0xFFE65100);
      badgeDotColor = const Color(0xFFFF9800);
      statusText = 'Pending';
    }

    final String initials = profile.name.trim().isNotEmpty
        ? profile.name.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase()
        : '?';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPending 
              ? const Color(0xFFD4B13B).withValues(alpha: 0.2) 
              : Colors.grey[200]!,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            setState(() {
              _selectedProfile = profile;
            });
          },
          child: Padding(
            padding: EdgeInsets.all(isTablet ? 18.0 : 16.0),
            child: Row(
              children: [
                Container(
                  width: isTablet ? 54 : 48,
                  height: isTablet ? 54 : 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isActive
                          ? [const Color(0xFFE8F5E9), const Color(0xFFC8E6C9)]
                          : [const Color(0xFFFFF6E5), const Color(0xFFF9E8B9)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isActive 
                          ? const Color(0xFF81C784) 
                          : const Color(0xFFD4B13B).withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: GoogleFonts.montserrat(
                        fontSize: isTablet ? 16 : 15,
                        fontWeight: FontWeight.bold,
                        color: isActive ? const Color(0xFF2E7D32) : const Color(0xFF8B6C1C),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
                        style: GoogleFonts.montserrat(
                          fontSize: isTablet ? 17 : 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E1E1E),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: badgeBgColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: badgeDotColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            statusText,
                            style: GoogleFonts.montserrat(
                              fontSize: isTablet ? 12 : 11,
                              fontWeight: FontWeight.bold,
                              color: badgeTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.grey[400],
                      size: isTablet ? 24 : 20,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddProfileButton(bool isTablet) {
    return GestureDetector(
      onTap: _showAddProfileDialog,
      child: CustomPaint(
        painter: DashedRectPainter(
          color: const Color(0xFFD4B13B),
          strokeWidth: 1.5,
          radius: 20,
        ),
        child: Container(
          width: double.infinity,
          height: isTablet ? 64 : 58,
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.person_add_alt_1_rounded,
                color: const Color(0xFF8B6C1C),
                size: isTablet ? 22 : 20,
              ),
              const SizedBox(width: 10),
              Text(
                'Add New Staff Profile',
                style: GoogleFonts.montserrat(
                  fontSize: isTablet ? 16 : 15,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF8B6C1C),
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
    final isTablet = AppResponsive.isTablet(context);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          elevation: 8,
          shadowColor: Colors.black.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(
              color: const Color(0xFFD4B13B).withValues(alpha: 0.1),
              width: 1.5,
            ),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isTablet ? 500 : 400),
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(isTablet ? 32.0 : 24.0),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFF3D0),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.person_add_alt_1_rounded,
                              color: Color(0xFF8B6C1C),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Add Staff Profile',
                            style: GoogleFonts.montserrat(
                              fontSize: isTablet ? 20 : 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E1E1E),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: nameController,
                        style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w500),
                        decoration: _inputDecoration(
                          hint: 'Staff Full Name',
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
                        style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w500),
                        decoration: _inputDecoration(
                          hint: 'Mobile Number (10 digits)',
                          prefixIcon: Icons.phone_outlined,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Mobile number is required';
                          }
                          if (value.trim().length < 10) {
                            return 'Enter a valid mobile number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.montserrat(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.bold,
                                fontSize: isTablet ? 15 : 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Consumer(
                            builder: (context, ref, _) {
                              return Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF2E6F40), Color(0xFF1E4620)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF1E4620).withValues(alpha: 0.15),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
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
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isTablet ? 24 : 20,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    'Add Profile',
                                    style: GoogleFonts.montserrat(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      fontSize: isTablet ? 15 : 14,
                                    ),
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
      fillColor: const Color(0xFFF9F9F9),
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
        borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  // ─── REQUEST ACCESS DETAIL VIEW ──────────────────────────────────────────
  Widget _buildRequestAccessView(
    UserProfileModel profile,
    UserProfilesState profilesState,
    bool isTablet,
  ) {
    final currentProfile = profilesState.profiles.firstWhere(
      (p) => p.id == profile.id,
      orElse: () => profile,
    );

    final isPending = currentProfile.status == 'pending_approval' ||
        currentProfile.requestPending;
        
    final isOtherDeviceSession = currentProfile.sessionActive && 
        currentProfile.approvedDeviceId != null && 
        currentProfile.approvedDeviceId != DeviceIdentity.androidId;
        
    final isMySession = currentProfile.sessionActive && 
        (currentProfile.approvedDeviceId == null || currentProfile.approvedDeviceId == DeviceIdentity.androidId);

    if (isPending && _countdownTimer == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _startTimers(currentProfile);
        }
      });
    }

    if (!isPending && _countdownTimer != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _stopTimers();
      });
    }

    return Column(
      key: const ValueKey('RequestAccessView'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            _stopTimers();
            setState(() {
              _selectedProfile = null;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back_ios_new_rounded, color: Colors.grey[700], size: 14),
                const SizedBox(width: 8),
                Text(
                  'Back to Profiles',
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFD4B13B).withValues(alpha: 0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD4B13B).withValues(alpha: 0.04),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: EdgeInsets.all(isTablet ? 32 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: isTablet ? 84 : 76,
                height: isTablet ? 84 : 76,
                decoration: BoxDecoration(
                  color: isOtherDeviceSession
                      ? const Color(0xFFFFF2F2)
                      : const Color(0xFFFFFDF0),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isOtherDeviceSession
                        ? const Color(0xFFFFCDD2)
                        : const Color(0xFFF9E8B9),
                    width: 2,
                  ),
                ),
                child: Icon(
                  isOtherDeviceSession
                      ? Icons.lock_outline_rounded
                      : Icons.person_rounded,
                  color: isOtherDeviceSession
                      ? const Color(0xFFD32F2F)
                      : const Color(0xFF8B6C1C),
                  size: isTablet ? 40 : 36,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                currentProfile.name,
                style: GoogleFonts.montserrat(
                  fontSize: isTablet ? 24 : 22,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E1E1E),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.phone_outlined, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 6),
                  Text(
                    currentProfile.mobile,
                    style: GoogleFonts.montserrat(
                      fontSize: isTablet ? 15 : 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isOtherDeviceSession
                      ? const Color(0xFFFFF2F2)
                      : isMySession
                          ? const Color(0xFFE8F5E9)
                          : isPending
                              ? const Color(0xFFFFF8E1)
                              : const Color(0xFFECEFF1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isOtherDeviceSession
                        ? const Color(0xFFFFCDD2)
                        : isMySession
                            ? const Color(0xFFA5D6A7)
                            : isPending
                                ? const Color(0xFFFFECB3)
                                : const Color(0xFFCFD8DC),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isOtherDeviceSession
                            ? const Color(0xFFD32F2F)
                            : isMySession
                                ? const Color(0xFF4CAF50)
                                : isPending
                                    ? const Color(0xFFFFB300)
                                    : const Color(0xFF78909C),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isOtherDeviceSession
                          ? 'Status: Active Session (Locked)'
                          : isMySession
                              ? 'Status: Active (This Device)'
                              : isPending
                                  ? 'Status: Pending Approval'
                                  : 'Status: Inactive',
                      style: GoogleFonts.montserrat(
                        fontSize: isTablet ? 13 : 12,
                        fontWeight: FontWeight.bold,
                        color: isOtherDeviceSession
                            ? const Color(0xFFD32F2F)
                            : isMySession
                                ? const Color(0xFF2E7D32)
                                : isPending
                                    ? const Color(0xFF8B6C1C)
                                    : const Color(0xFF546E7A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        if (isOtherDeviceSession) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF2F2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFFCDD2), width: 1.5),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFCDD2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    color: Color(0xFFD32F2F),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Session Lock Active',
                        style: GoogleFonts.montserrat(
                          fontSize: isTablet ? 15 : 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFD32F2F),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'This profile is currently logged in on another device. For security, concurrent login requests are blocked.',
                        style: GoogleFonts.montserrat(
                          fontSize: isTablet ? 13 : 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF7A1C1C),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: isTablet ? 64 : 56,
            child: ElevatedButton(
              onPressed: null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[200],
                disabledBackgroundColor: Colors.grey[200],
                disabledForegroundColor: Colors.grey[500],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.block_rounded, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Request Blocked',
                    style: GoogleFonts.montserrat(
                      fontSize: isTablet ? 16 : 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ] else if (isPending) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFDF5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF9E8B9), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD4B13B).withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4B13B)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Your account is waiting for admin approval.',
                        style: GoogleFonts.montserrat(
                          fontSize: isTablet ? 14 : 13,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF8B6C1C),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Color(0xFFF9E8B9)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Time remaining:',
                      style: GoogleFonts.montserrat(
                        fontSize: isTablet ? 14 : 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 18,
                          color: _remainingSeconds <= 30
                              ? const Color(0xFFD32F2F)
                              : const Color(0xFFD4B13B),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$_remainingSeconds seconds',
                          style: GoogleFonts.montserrat(
                            fontSize: isTablet ? 15 : 14,
                            fontWeight: FontWeight.bold,
                            color: _remainingSeconds <= 30
                                ? const Color(0xFFD32F2F)
                                : const Color(0xFF8B6C1C),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _remainingSeconds / 300.0,
                    backgroundColor: const Color(0xFFF4EDE4),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _remainingSeconds <= 30
                          ? const Color(0xFFD32F2F)
                          : const Color(0xFFD4B13B),
                    ),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: isTablet ? 64 : 56,
            child: OutlinedButton(
              onPressed: () {
                _stopTimers();
                setState(() {
                  _selectedProfile = null;
                });
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFD4B13B), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cancel_outlined, color: Color(0xFF8B6C1C), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Cancel Request',
                    style: GoogleFonts.montserrat(
                      fontSize: isTablet ? 16 : 15,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF8B6C1C),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ] else if (isMySession) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFA5D6A7), width: 1.5),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xFFC8E6C9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF2E7D32),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Active Session on This Device',
                        style: GoogleFonts.montserrat(
                          fontSize: isTablet ? 15 : 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2E7D32),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'You are already approved on this device. Resume without asking the admin again.',
                        style: GoogleFonts.montserrat(
                          fontSize: isTablet ? 13 : 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF1B5E20),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: isTablet ? 64 : 56,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  colors: [Color(0xFF2E6F40), Color(0xFF1E4620)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E4620).withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  _stopTimers();
                  ref.read(authStateProvider.notifier).loginAsStaff(currentProfile);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.login_rounded, color: Colors.white, size: isTablet ? 22 : 20),
                    const SizedBox(width: 8),
                    Text(
                      'Resume Session',
                      style: GoogleFonts.montserrat(
                        fontSize: isTablet ? 16 : 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ] else
          SizedBox(
            width: double.infinity,
            height: isTablet ? 64 : 56,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  colors: profilesState.isLoading
                      ? [const Color(0xFF7CA081), const Color(0xFF7CA081)]
                      : [const Color(0xFF2E6F40), const Color(0xFF1E4620)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E4620).withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: profilesState.isLoading
                    ? null
                    : () async {
                        final success = await ref
                            .read(userProfilesNotifierProvider.notifier)
                            .sendAccessRequest(currentProfile.id);
                        if (success && mounted) {
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
                        } else if (mounted) {
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
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
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
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send_rounded, color: Colors.white, size: isTablet ? 22 : 20),
                          const SizedBox(width: 8),
                          Text(
                            'Send Request to Access',
                            style: GoogleFonts.montserrat(
                              fontSize: isTablet ? 16 : 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
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
