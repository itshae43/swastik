import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swastik_mobile_app/features/auth/models/user_profile.dart';
import 'package:swastik_mobile_app/services/api_service.dart';

final apiServiceProvider = Provider<ApiService>((ref) => ApiService(ref));

class UserProfilesState {
  final List<UserProfileModel> profiles;
  final bool isLoading;
  final String? error;
  final bool requestSuccess;

  UserProfilesState({
    required this.profiles,
    required this.isLoading,
    this.error,
    this.requestSuccess = false,
  });

  UserProfilesState copyWith({
    List<UserProfileModel>? profiles,
    bool? isLoading,
    String? error,
    bool? requestSuccess,
  }) {
    return UserProfilesState(
      profiles: profiles ?? this.profiles,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      requestSuccess: requestSuccess ?? this.requestSuccess,
    );
  }
}

class UserProfilesNotifier extends Notifier<UserProfilesState> {
  @override
  UserProfilesState build() {
    Future.microtask(() => fetchProfiles());
    return UserProfilesState(profiles: [], isLoading: false);
  }

  Future<void> fetchProfiles() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final apiService = ref.read(apiServiceProvider);
      final jsonList = await apiService.getUserProfiles();
      final profiles = jsonList.map((item) => UserProfileModel.fromJson(item)).toList();
      state = state.copyWith(profiles: profiles, isLoading: false);
    } catch (e) {
      debugPrint('[UserProfilesNotifier] Error fetching profiles: $e');
      state = state.copyWith(isLoading: false, error: 'Failed to load profiles');
    }
  }

  Future<bool> addProfile(String name, String mobile) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      String model = 'Unknown';
      String platform = 'unknown';
      try {
        final deviceInfoPlugin = DeviceInfoPlugin();
        if (Platform.isAndroid) {
          final androidInfo = await deviceInfoPlugin.androidInfo;
          model = androidInfo.model;
          platform = 'android';
        } else if (Platform.isIOS) {
          final iosInfo = await deviceInfoPlugin.iosInfo;
          model = iosInfo.model;
          platform = 'ios';
        }
      } catch (e) {
        debugPrint('Error getting device info: $e');
      }

      final body = {
        'name': name,
        'mobile': mobile,
        'deviceInfo': {
          'deviceModel': model,
          'platform': platform,
        }
      };

      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.createUserProfile(body);
      final newProfile = UserProfileModel.fromJson(response);
      state = state.copyWith(
        profiles: [newProfile, ...state.profiles],
        isLoading: false,
      );
      return true;
    } catch (e) {
      debugPrint('[UserProfilesNotifier] Error creating profile: $e');
      state = state.copyWith(isLoading: false, error: 'Failed to create profile');
      return false;
    }
  }

  Future<bool> sendAccessRequest(String id) async {
    state = state.copyWith(isLoading: true, error: null, requestSuccess: false);
    try {
      String model = 'Unknown';
      String platform = 'unknown';
      try {
        final deviceInfoPlugin = DeviceInfoPlugin();
        if (Platform.isAndroid) {
          final androidInfo = await deviceInfoPlugin.androidInfo;
          model = androidInfo.model;
          platform = 'android';
        } else if (Platform.isIOS) {
          final iosInfo = await deviceInfoPlugin.iosInfo;
          model = iosInfo.model;
          platform = 'ios';
        }
      } catch (e) {
        debugPrint('Error getting device info: $e');
      }

      final deviceInfo = {
        'deviceModel': model,
        'platform': platform,
      };

      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.requestProfileAccess(id, deviceInfo);
      final updatedProfile = UserProfileModel.fromJson(response);

      // Update state with the updated profile
      final updatedProfiles = state.profiles.map((p) {
        return p.id == id ? updatedProfile : p;
      }).toList();

      state = state.copyWith(
        profiles: updatedProfiles,
        isLoading: false,
        requestSuccess: true,
      );
      return true;
    } catch (e) {
      debugPrint('[UserProfilesNotifier] Error requesting access: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to send access request',
        requestSuccess: false,
      );
      return false;
    }
  }

  Future<bool> approveProfile(String id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.approveProfileAccess(id);
      final updatedProfile = UserProfileModel.fromJson(response);

      final updatedProfiles = state.profiles.map((p) {
        return p.id == id ? updatedProfile : p;
      }).toList();

      state = state.copyWith(
        profiles: updatedProfiles,
        isLoading: false,
      );
      return true;
    } catch (e) {
      debugPrint('[UserProfilesNotifier] Error approving profile: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to approve profile access',
      );
      return false;
    }
  }

  Future<bool> declineProfile(String id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.declineProfileAccess(id);
      final updatedProfile = UserProfileModel.fromJson(response);

      final updatedProfiles = state.profiles.map((p) {
        return p.id == id ? updatedProfile : p;
      }).toList();

      state = state.copyWith(
        profiles: updatedProfiles,
        isLoading: false,
      );
      return true;
    } catch (e) {
      debugPrint('[UserProfilesNotifier] Error declining profile: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to decline profile access',
      );
      return false;
    }
  }
}

final userProfilesNotifierProvider =
    NotifierProvider<UserProfilesNotifier, UserProfilesState>(UserProfilesNotifier.new);
