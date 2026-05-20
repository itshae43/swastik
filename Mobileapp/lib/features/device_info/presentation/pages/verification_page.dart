import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/device_info.dart';
import '../providers/device_info_provider.dart';
import '../providers/verification_provider.dart';
import '../../../hello_world/presentation/pages/greeting_page.dart';

class VerificationPage extends ConsumerStatefulWidget {
  const VerificationPage({super.key});

  @override
  ConsumerState<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends ConsumerState<VerificationPage> {
  bool _isAdminSelected = true;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleVerification() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. If Other User is selected, block immediately
      if (!_isAdminSelected) {
        setState(() {
          _errorMessage = 'Please contact to admin';
          _isLoading = false;
        });
        return;
      }

      // 2. Fetch current device info state
      final deviceInfoAsyncValue = ref.read(deviceInfoFutureProvider);
      
      final DeviceInfo deviceInfo;
      if (deviceInfoAsyncValue is AsyncData<DeviceInfo>) {
        deviceInfo = deviceInfoAsyncValue.value;
      } else {
        // If not loaded yet, await it
        deviceInfo = await ref.read(deviceInfoFutureProvider.future);
      }

      debugPrint('Device Info for verification: brand=${deviceInfo.brand}, model=${deviceInfo.model}, androidId=${deviceInfo.androidId}');

      // 3. Make request via verification repository provider
      final verificationRepo = ref.read(verificationRepositoryProvider);
      final result = await verificationRepo.verifyDevice(deviceInfo);

      if (result['verified'] == true) {
        setState(() {
          _isLoading = false;
        });

        // Safe transition after animation delay
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Device verified successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const GreetingPage()),
          );
        }
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Please contact to admin';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Verification Error: $e');
      setState(() {
        _errorMessage = 'Connection error. Please ensure backend is running.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCF9F4),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Title
                const Text(
                  "Let's Get Started!",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C3E2B),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 32),

                // Toggle tabs container (Admin vs Other User)
                Container(
                  height: 56,
                  padding: const EdgeInsets.all(4.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3EDE2),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Row(
                    children: [
                      // Admin Tab
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _isAdminSelected = true;
                              _errorMessage = null;
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: _isAdminSelected
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: _isAdminSelected
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withAlpha(12),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      )
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.person,
                                  color: _isAdminSelected
                                      ? const Color(0xFF86723B)
                                      : const Color(0xFF8C867A),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Admin',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: _isAdminSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: _isAdminSelected
                                        ? const Color(0xFF86723B)
                                        : const Color(0xFF8C867A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      // Other User Tab
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _isAdminSelected = false;
                              _errorMessage = null;
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: !_isAdminSelected
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: !_isAdminSelected
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withAlpha(12),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      )
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.person_outline,
                                  color: !_isAdminSelected
                                      ? const Color(0xFF86723B)
                                      : const Color(0xFF8C867A),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Other User',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: !_isAdminSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: !_isAdminSelected
                                        ? const Color(0xFF86723B)
                                        : const Color(0xFF8C867A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),

                // Click to Verify Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleVerification,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E4620),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF1E4620).withAlpha(153),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(27),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Click to Verify',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.1,
                            ),
                          ),
                  ),
                ),

                // Error Message Container
                if (_errorMessage != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDE8E8),
                      border: Border.all(color: const Color(0xFFF8B4B4)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Color(0xFFE02424),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF9B1C1C),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
