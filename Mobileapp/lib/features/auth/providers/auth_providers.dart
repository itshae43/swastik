import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:android_id/android_id.dart';
import 'package:swastik_mobile_app/core/services/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

enum AuthStatus { initial, loading, unverified, verified, error }

class AuthNotifier extends Notifier<AuthStatus> {
  @override
  AuthStatus build() {
    // Start verification immediately
    Future.microtask(() => verify());
    return AuthStatus.initial;
  }

  Future<void> verify() async {
    state = AuthStatus.loading;
    try {
      final isVerified = await ref.read(authServiceProvider).verifyDevice();
      state = isVerified ? AuthStatus.verified : AuthStatus.unverified;
      debugPrint('[AuthNotifier] Verification result: $state');
    } catch (e) {
      debugPrint('[AuthNotifier] Verification FAILED with error: $e');
      state = AuthStatus.error;
    }
  }

  void logout() {
    state = AuthStatus.unverified;
  }

  void logoutLocal() {
    state = AuthStatus.unverified;
  }
}

final authStateProvider = NotifierProvider<AuthNotifier, AuthStatus>(AuthNotifier.new);

class DevicesNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    // Fetch real device ID if available to match "This Device"
    String? currentAndroidId;
    try {
      const androidIdPlugin = AndroidId();
      currentAndroidId = await androidIdPlugin.getId();
    } catch (e) {
      debugPrint('[DevicesNotifier] Error reading androidId: $e');
    }

    return [
      {
        'id': 'session_1',
        'userName': 'Shailendra',
        'phoneNumber': '9876543210',
        'brand': 'Google',
        'model': 'Pixel 6',
        'androidId': currentAndroidId ?? 'current_device_id',
        'lastActive': 'Active Now'
      },
      {
        'id': 'session_2',
        'userName': 'John Doe',
        'phoneNumber': '9876543211',
        'brand': 'Samsung',
        'model': 'Galaxy Tab S9',
        'androidId': 'mock_id_2',
        'lastActive': 'Active 10 mins ago'
      },
      {
        'id': 'session_3',
        'userName': 'Jane Smith',
        'phoneNumber': '9876543212',
        'brand': 'Apple',
        'model': 'iPad Pro',
        'androidId': 'mock_id_3',
        'lastActive': 'Active 2 hours ago'
      },
      {
        'id': 'session_4',
        'userName': 'Ramesh Kumar',
        'phoneNumber': '9876543213',
        'brand': 'OnePlus',
        'model': 'OnePlus 11',
        'androidId': 'mock_id_4',
        'lastActive': 'Active 1 day ago'
      }
    ];
  }

  Future<bool> deauthorizeDevice(String id) async {
    final list = state.value;
    if (list != null) {
      state = AsyncValue.data(list.where((device) => device['id'] != id).toList());
    }
    return true;
  }
}

final devicesProvider = AsyncNotifierProvider.autoDispose<DevicesNotifier, List<Map<String, dynamic>>>(DevicesNotifier.new);



