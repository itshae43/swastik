import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swastik_mobile_app/core/services/auth_service.dart';
import 'package:swastik_mobile_app/features/auth/models/user_profile.dart';
import 'package:swastik_mobile_app/features/auth/providers/user_profiles_provider.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

class CurrentUserProfileNotifier extends Notifier<UserProfileModel?> {
  @override
  UserProfileModel? build() => null;

  void setProfile(UserProfileModel? profile) {
    state = profile;
  }
}

final currentUserProfileProvider = NotifierProvider<CurrentUserProfileNotifier, UserProfileModel?>(CurrentUserProfileNotifier.new);
final isStaffProvider = Provider<bool>((ref) => ref.watch(currentUserProfileProvider) != null);

enum AuthStatus { initial, loading, unverified, verified, error }

class AuthNotifier extends Notifier<AuthStatus> {
  Timer? _logoutTimer;
  Timer? _pollingTimer;
  DateTime? _localLastApprovalTime;

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

  void loginAsStaff(UserProfileModel profile) {
    ref.read(currentUserProfileProvider.notifier).setProfile(profile);
    state = AuthStatus.verified;
    _localLastApprovalTime = profile.lastApprovalTime;

    _logoutTimer?.cancel();
    _pollingTimer?.cancel();
    
    if (profile.expiresAt != null) {
      final diff = profile.expiresAt!.difference(DateTime.now());
      if (diff.isNegative) {
        logoutLocal();
        return;
      } else {
        _logoutTimer = Timer(diff, () {
          logoutLocal();
        });
      }
    }

    // Start polling the backend for session status
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        await ref.read(userProfilesNotifierProvider.notifier).fetchProfiles();
        final profilesState = ref.read(userProfilesNotifierProvider);
        
        final updatedProfile = profilesState.profiles.firstWhere(
          (p) => p.id == profile.id,
          orElse: () => profile,
        );
        
        if (!updatedProfile.sessionActive || updatedProfile.status == 'inactive') {
          debugPrint('[AuthNotifier] Session invalidated remotely. Logging out.');
          logoutLocal();
        } else if (_localLastApprovalTime != null && 
                   updatedProfile.lastApprovalTime != null && 
                   updatedProfile.lastApprovalTime!.isAfter(_localLastApprovalTime!)) {
          debugPrint('[AuthNotifier] New device approved. Logging out old device.');
          logoutLocal();
        }
      } catch (e) {
        debugPrint('[AuthNotifier] Polling error: $e');
      }
    });
  }

  Future<bool> logout() async {
    final profile = ref.read(currentUserProfileProvider);
    if (profile == null) {
      logoutLocal();
      return true;
    }

    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isEmpty || result[0].rawAddress.isEmpty) {
        throw Exception('Offline');
      }
    } on SocketException catch (_) {
      debugPrint('[AuthNotifier] Offline, cannot logout.');
      return false; // Offline
    }

    // Online, call API
    try {
      final success = await ref.read(authServiceProvider).deauthorizeDevice(profile.id);
      if (success) {
        logoutLocal();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[AuthNotifier] API error during logout: $e');
      return false;
    }
  }

  void logoutLocal() {
    _logoutTimer?.cancel();
    _pollingTimer?.cancel();
    ref.read(currentUserProfileProvider.notifier).setProfile(null);
    state = AuthStatus.unverified;
  }
}

final authStateProvider = NotifierProvider<AuthNotifier, AuthStatus>(AuthNotifier.new);

class DevicesNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    try {
      final devices = await ref.read(authServiceProvider).getDevices();
      return devices;
    } catch (e) {
      debugPrint('[DevicesNotifier] Error fetching devices: $e');
      return [];
    }
  }

  Future<bool> deauthorizeDevice(String id) async {
    try {
      final success = await ref.read(authServiceProvider).deauthorizeDevice(id);
      if (success) {
        final list = state.value;
        if (list != null) {
          state = AsyncValue.data(list.where((device) => device['id'].toString() != id).toList());
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[DevicesNotifier] Error deauthorizing device $id: $e');
      return false;
    }
  }
}

final devicesProvider = AsyncNotifierProvider.autoDispose<DevicesNotifier, List<Map<String, dynamic>>>(DevicesNotifier.new);



