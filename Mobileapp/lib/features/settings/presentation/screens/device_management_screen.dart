import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:android_id/android_id.dart';
import 'package:swastik_mobile_app/core/utils/responsive_utils.dart';
import 'package:swastik_mobile_app/features/auth/providers/auth_providers.dart';
import 'package:swastik_mobile_app/features/auth/models/user_profile.dart';
import 'package:swastik_mobile_app/features/auth/providers/user_profiles_provider.dart';

class DeviceManagementScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;
  const DeviceManagementScreen({super.key, this.initialTabIndex = 0});

  @override
  ConsumerState<DeviceManagementScreen> createState() => _DeviceManagementScreenState();
}

class _DeviceManagementScreenState extends ConsumerState<DeviceManagementScreen> {
  String? _currentAndroidId;
  bool _loadingId = true;
  int _activeTabIndex = 0; // 0 for Active Devices, 1 for Pending Requests

  @override
  void initState() {
    super.initState();
    _activeTabIndex = widget.initialTabIndex;
    _loadCurrentDeviceId();
  }

  Future<void> _loadCurrentDeviceId() async {
    try {
      const androidIdPlugin = AndroidId();
      final androidId = await androidIdPlugin.getId();
      if (mounted) {
        setState(() {
          _currentAndroidId = androidId;
          _loadingId = false;
        });
      }
    } catch (e) {
      debugPrint('[DeviceManagementScreen] Error loading android ID: $e');
      if (mounted) {
        setState(() {
          _loadingId = false;
        });
      }
    }
  }

  Future<void> _showLogoutConfirmation(BuildContext context, Map<String, dynamic> device) async {
    final isTablet = AppResponsive.isTablet(context);
    final isCurrent = _currentAndroidId != null &&
        device['androidId'].toString().toLowerCase() == _currentAndroidId!.toLowerCase();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFAF6EE),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isTablet ? 24 : 18),
            side: const BorderSide(color: Color(0xFFD4B13B), width: 1),
          ),
          title: Text(
            isCurrent ? 'Logout This Device?' : 'Logout Remote Device?',
            style: GoogleFonts.montserrat(
              fontSize: isTablet ? 20 : 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E1E1E),
            ),
          ),
          content: Text(
            isCurrent
                ? 'Are you sure you want to log out from this device? You will need to verify this device again to access your account.'
                : 'Are you sure you want to log out ${device['brand']} ${device['model']} (${device['userName']})? This device will lose access to the ledger immediately.',
            style: GoogleFonts.montserrat(
              fontSize: isTablet ? 15 : 14,
              color: const Color(0xFF555555),
              height: 1.5,
            ),
          ),
          actionsPadding: EdgeInsets.symmetric(
            horizontal: isTablet ? 20 : 16,
            vertical: isTablet ? 16 : 12,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancel',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                  fontSize: isTablet ? 15 : 14,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC62828),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 20 : 16,
                  vertical: isTablet ? 10 : 8,
                ),
              ),
              child: Text(
                'Logout',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.bold,
                  fontSize: isTablet ? 15 : 14,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      _performLogout(device['id'].toString(), isCurrent);
    }
  }

  Future<void> _performLogout(String sessionId, bool isCurrent) async {
    // Show loading overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4B13B)),
        ),
      ),
    );

    final success = await ref.read(devicesProvider.notifier).deauthorizeDevice(sessionId);

    if (mounted) {
      Navigator.of(context).pop(); // Dismiss loading overlay
      if (success) {
        if (isCurrent) {
          ref.read(authStateProvider.notifier).logoutLocal();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF13331E),
              content: Text(
                'Device logged out successfully.',
                style: GoogleFonts.montserrat(color: Colors.white),
              ),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFC62828),
            content: Text(
              'Failed to log out device. Please try again.',
              style: GoogleFonts.montserrat(color: Colors.white),
            ),
          ),
        );
      }
    }
  }

  Widget _buildTabBar(bool isTablet) {
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
              label: 'Active Devices',
              icon: Icons.devices_rounded,
              isActive: _activeTabIndex == 0,
              isTablet: isTablet,
              onTap: () {
                setState(() {
                  _activeTabIndex = 0;
                });
              },
            ),
          ),
          Expanded(
            child: _buildTabButton(
              label: 'Pending Requests',
              icon: Icons.pending_actions_rounded,
              isActive: _activeTabIndex == 1,
              isTablet: isTablet,
              onTap: () {
                setState(() {
                  _activeTabIndex = 1;
                });
                ref.read(userProfilesNotifierProvider.notifier).fetchProfiles();
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
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
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
              color: isActive ? const Color(0xFF1E4620) : Colors.grey[600],
              size: isTablet ? 20 : 16,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.montserrat(
                color: isActive ? const Color(0xFF1E4620) : Colors.grey[600],
                fontSize: isTablet ? 14 : 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(devicesProvider);
    final profilesState = ref.watch(userProfilesNotifierProvider);
    final isTablet = AppResponsive.isTablet(context);

    return Scaffold(
      backgroundColor: isTablet ? const Color(0xFFFAF6EE) : const Color(0xFFFDFBF7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: const Color(0xFF1E1E1E),
            size: isTablet ? 24 : 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Device Management',
          style: GoogleFonts.montserrat(
            fontSize: isTablet ? 22 : 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E1E1E),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 28.0 : 20.0,
                vertical: 8.0,
              ),
              child: _buildTabBar(isTablet),
            ),
            Expanded(
              child: _activeTabIndex == 0
                  ? (_loadingId
                      ? const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4B13B)),
                          ),
                        )
                      : devicesAsync.when(
                          data: (devices) {
                            if (devices.isEmpty) {
                              return _buildEmptyState(isTablet);
                            }
                            return RefreshIndicator(
                              onRefresh: () async {
                                ref.invalidate(devicesProvider);
                              },
                              color: const Color(0xFFD4B13B),
                              child: ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: EdgeInsets.symmetric(
                                  horizontal: isTablet ? 28.0 : 20.0,
                                  vertical: isTablet ? 16.0 : 12.0,
                                ),
                                itemCount: devices.length + 1,
                                itemBuilder: (context, index) {
                                  if (index == 0) {
                                    return Padding(
                                      padding: EdgeInsets.only(bottom: isTablet ? 24.0 : 20.0),
                                      child: Text(
                                        'These devices are currently logged in to your account. You can log out of individual sessions remotely.',
                                        style: GoogleFonts.montserrat(
                                          fontSize: isTablet ? 15 : 13.5,
                                          color: Colors.grey[600],
                                          height: 1.5,
                                        ),
                                      ),
                                    );
                                  }

                                  final device = devices[index - 1];
                                  final isCurrent = _currentAndroidId != null &&
                                      device['androidId'].toString().toLowerCase() ==
                                          _currentAndroidId!.toLowerCase();

                                  return _buildDeviceCard(device, isCurrent, isTablet);
                                },
                              ),
                            );
                          },
                          loading: () => const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4B13B)),
                            ),
                          ),
                          error: (error, stack) => _buildErrorState(error, isTablet),
                        ))
                  : (profilesState.isLoading && profilesState.profiles.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4B13B)),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () async {
                            await ref.read(userProfilesNotifierProvider.notifier).fetchProfiles();
                          },
                          color: const Color(0xFFD4B13B),
                          child: () {
                            final pendingProfiles = profilesState.profiles
                                .where((p) {
                                  final isPending = p.status == 'pending_approval' || p.requestPending == true;
                                  if (!isPending) return false;
                                  final diff = DateTime.now().difference(p.requestedAt ?? p.createdAt ?? DateTime.now());
                                  return diff.inMinutes < 5;
                                })
                                .toList();
                            if (pendingProfiles.isEmpty) {
                              return _buildEmptyPendingRequestsState(isTablet);
                            }
                            return ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.symmetric(
                                horizontal: isTablet ? 28.0 : 20.0,
                                vertical: isTablet ? 16.0 : 12.0,
                              ),
                              itemCount: pendingProfiles.length,
                              itemBuilder: (context, index) {
                                final profile = pendingProfiles[index];
                                return _PendingRequestItem(
                                  profile: profile,
                                  isTablet: isTablet,
                                  onApprove: () async {
                                    final success = await ref
                                        .read(userProfilesNotifierProvider.notifier)
                                        .approveProfile(profile.id);
                                    if (success && context.mounted) {
                                      ref.invalidate(devicesProvider);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          backgroundColor: const Color(0xFF1E4620),
                                          content: Text(
                                            'Access request approved successfully!',
                                            style: GoogleFonts.montserrat(color: Colors.white),
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  onDecline: () async {
                                    final success = await ref
                                        .read(userProfilesNotifierProvider.notifier)
                                        .declineProfile(profile.id);
                                    if (success && context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          backgroundColor: const Color(0xFFD32F2F),
                                          content: Text(
                                            'Access request declined.',
                                            style: GoogleFonts.montserrat(color: Colors.white),
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                );
                              },
                            );
                          }(),
                        )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceCard(Map<String, dynamic> device, bool isCurrent, bool isTablet) {
    final modelName = device['model'] ?? 'Unknown Device';
    final brandName = device['brand'] ?? '';
    final userName = device['userName'] ?? 'User';
    final phoneNumber = device['phoneNumber'] ?? '';
    final lastActive = device['lastActive'] ?? 'Active now';

    final isTabletDevice = modelName.toString().toLowerCase().contains('tablet') ||
        modelName.toString().toLowerCase().contains('ipad');

    return Container(
      margin: EdgeInsets.only(bottom: isTablet ? 16 : 12),
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
        border: Border.all(
          color: isCurrent
              ? const Color(0xFFD4B13B).withValues(alpha: 0.5)
              : Colors.grey.withValues(alpha: 0.12),
          width: isCurrent ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isCurrent
                ? const Color(0xFFD4B13B).withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Device Icon Container
          Container(
            padding: EdgeInsets.all(isTablet ? 12 : 10),
            decoration: BoxDecoration(
              color: isCurrent ? const Color(0xFFFFF3D0) : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isTabletDevice ? Icons.tablet_android_rounded : Icons.phone_android_rounded,
              color: isCurrent ? const Color(0xFF8A7311) : Colors.grey[600],
              size: isTablet ? 28 : 24,
            ),
          ),
          SizedBox(width: isTablet ? 18 : 14),

          // Device Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        '$brandName $modelName'.trim(),
                        style: GoogleFonts.montserrat(
                          fontSize: isTablet ? 17 : 15,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E1E1E),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF13331E),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'THIS DEVICE',
                          style: GoogleFonts.montserrat(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFD4B13B),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '$userName • $phoneNumber',
                  style: GoogleFonts.montserrat(
                    fontSize: isTablet ? 14 : 12.5,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: lastActive.toString().toLowerCase().contains('now')
                            ? const Color(0xFF2E7D32)
                            : Colors.grey[400],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      lastActive,
                      style: GoogleFonts.montserrat(
                        fontSize: isTablet ? 13 : 11.5,
                        fontWeight: FontWeight.w500,
                        color: lastActive.toString().toLowerCase().contains('now')
                            ? const Color(0xFF2E7D32)
                            : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: isTablet ? 16 : 12),

          // Logout Action Button
          IconButton(
            icon: Icon(
              Icons.logout_rounded,
              color: const Color(0xFFC62828),
              size: isTablet ? 24 : 20,
            ),
            tooltip: 'Log out device',
            onPressed: () => _showLogoutConfirmation(context, device),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isTablet) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.devices_other_rounded,
              size: isTablet ? 72 : 60,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'No Devices Found',
              style: GoogleFonts.montserrat(
                fontSize: isTablet ? 18 : 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E1E1E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Currently there are no registered devices or sessions connected to this account.',
              style: GoogleFonts.montserrat(
                fontSize: isTablet ? 14 : 13,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyPendingRequestsState(bool isTablet) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: isTablet ? 72 : 60,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'No Pending Requests',
              style: GoogleFonts.montserrat(
                fontSize: isTablet ? 18 : 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E1E1E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'All staff access requests have been processed.',
              style: GoogleFonts.montserrat(
                fontSize: isTablet ? 14 : 13,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(Object error, bool isTablet) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: isTablet ? 72 : 60,
              color: const Color(0xFFC62828),
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to Load Devices',
              style: GoogleFonts.montserrat(
                fontSize: isTablet ? 18 : 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E1E1E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please check your internet connection and make sure the Swastik backend is running.',
              style: GoogleFonts.montserrat(
                fontSize: isTablet ? 14 : 13,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                ref.invalidate(devicesProvider);
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4B13B),
                foregroundColor: const Color(0xFF13331E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 24 : 20,
                  vertical: isTablet ? 12 : 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingRequestItem extends StatefulWidget {
  final UserProfileModel profile;
  final bool isTablet;
  final Future<void> Function() onApprove;
  final Future<void> Function() onDecline;

  const _PendingRequestItem({
    required this.profile,
    required this.isTablet,
    required this.onApprove,
    required this.onDecline,
  });

  @override
  State<_PendingRequestItem> createState() => _PendingRequestItemState();
}

class _PendingRequestItemState extends State<_PendingRequestItem> {
  late int _remainingSeconds;
  Timer? _timer;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _calculateRemaining();
    _startTimer();
  }

  void _calculateRemaining() {
    final requestedAt = widget.profile.requestedAt ?? widget.profile.createdAt;
    final totalSeconds = 5 * 60; // 5 minutes
    if (requestedAt != null) {
      final diff = DateTime.now().difference(requestedAt).inSeconds;
      _remainingSeconds = (totalSeconds - diff).clamp(0, totalSeconds);
    } else {
      _remainingSeconds = totalSeconds;
    }
  }

  void _startTimer() {
    if (_remainingSeconds <= 0) {
      _handleExpiry();
      return;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
          } else {
            _timer?.cancel();
            _handleExpiry();
          }
        });
      }
    });
  }

  Future<void> _handleExpiry() async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
    });
    await widget.onDecline();
    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = widget.isTablet;
    final isUrgent = _remainingSeconds <= 30;
    final avatarColor = isUrgent ? const Color(0xFFFFF2F2) : const Color(0xFFFAF6EE);
    final avatarIconColor = isUrgent ? const Color(0xFFD32F2F) : const Color(0xFF8A7311);

    return Container(
      margin: EdgeInsets.only(bottom: isTablet ? 16 : 12),
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
        border: Border.all(
          color: isUrgent
              ? const Color(0xFFD32F2F).withValues(alpha: 0.3)
              : const Color(0xFFD4B13B).withValues(alpha: 0.12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar icon
              Container(
                padding: EdgeInsets.all(isUrgent ? 10 : 8),
                decoration: BoxDecoration(
                  color: avatarColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_outline_rounded,
                  color: avatarIconColor,
                  size: isTablet ? 24 : 20,
                ),
              ),
              const SizedBox(width: 12),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.profile.name,
                      style: GoogleFonts.montserrat(
                        fontSize: isTablet ? 16 : 14.5,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E1E1E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.profile.mobile,
                      style: GoogleFonts.montserrat(
                        fontSize: isTablet ? 13.5 : 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (widget.profile.deviceInfo.deviceModel.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4EDE4),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Device: ${widget.profile.deviceInfo.deviceModel} (${widget.profile.deviceInfo.platform.toUpperCase()})',
                          style: GoogleFonts.montserrat(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF555555),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Countdown Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isUrgent
                      ? const Color(0xFFFFF2F2)
                      : const Color(0xFFFFFDF5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isUrgent
                        ? const Color(0xFFD32F2F).withValues(alpha: 0.5)
                        : const Color(0xFFD4B13B).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 13,
                      color: isUrgent ? const Color(0xFFD32F2F) : const Color(0xFFD4B13B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_remainingSeconds}s',
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isUrgent ? const Color(0xFFD32F2F) : const Color(0xFFD4B13B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: _isProcessing
                    ? null
                    : () async {
                        setState(() {
                          _isProcessing = true;
                        });
                        await widget.onDecline();
                        if (mounted) {
                          setState(() {
                            _isProcessing = false;
                          });
                        }
                      },
                icon: const Icon(Icons.close_rounded, size: 16),
                label: Text(
                  'Decline',
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFD32F2F),
                  side: const BorderSide(color: Color(0xFFD32F2F)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 18 : 14,
                    vertical: isTablet ? 10 : 8,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _isProcessing
                    ? null
                    : () async {
                        setState(() {
                          _isProcessing = true;
                        });
                        await widget.onApprove();
                        if (mounted) {
                          setState(() {
                            _isProcessing = false;
                          });
                        }
                      },
                icon: _isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.check_rounded, size: 16),
                label: Text(
                  'Approve',
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E4620),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 18 : 14,
                    vertical: isTablet ? 10 : 8,
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
