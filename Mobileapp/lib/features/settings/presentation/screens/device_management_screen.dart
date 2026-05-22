import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:android_id/android_id.dart';
import 'package:swastik_mobile_app/core/utils/responsive_utils.dart';
import 'package:swastik_mobile_app/features/auth/providers/auth_providers.dart';

class DeviceManagementScreen extends ConsumerStatefulWidget {
  const DeviceManagementScreen({super.key});

  @override
  ConsumerState<DeviceManagementScreen> createState() => _DeviceManagementScreenState();
}

class _DeviceManagementScreenState extends ConsumerState<DeviceManagementScreen> {
  String? _currentAndroidId;
  bool _loadingId = true;

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(devicesProvider);
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
        child: _loadingId
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
              ? const Color(0xFFD4B13B).withOpacity(0.5)
              : Colors.grey.withOpacity(0.12),
          width: isCurrent ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isCurrent
                ? const Color(0xFFD4B13B).withOpacity(0.06)
                : Colors.black.withOpacity(0.02),
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
