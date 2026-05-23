import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swastik_mobile_app/features/auth/providers/auth_providers.dart';

class ProfileState {
  final String name;
  final int gradientIndex;
  final int iconIndex; // -1 for Monogram (initial letter), 0..5 for specific icons

  ProfileState({
    required this.name,
    required this.gradientIndex,
    required this.iconIndex,
  });

  ProfileState copyWith({
    String? name,
    int? gradientIndex,
    int? iconIndex,
  }) {
    return ProfileState(
      name: name ?? this.name,
      gradientIndex: gradientIndex ?? this.gradientIndex,
      iconIndex: iconIndex ?? this.iconIndex,
    );
  }
}

class ProfileNotifier extends Notifier<ProfileState> {
  ProfileNotifier(this.arg);
  final String? arg;
  late final String _storagePrefix;

  @override
  ProfileState build() {
    _storagePrefix = arg == null ? 'admin' : 'staff_$arg';

    // Try to get default name for Staff
    String defaultName = 'Admin';
    if (arg != null) {
      final currentStaff = ref.watch(currentUserProfileProvider);
      if (currentStaff != null && currentStaff.id == arg) {
        defaultName = currentStaff.name;
      }
    }

    final initialState = ProfileState(
      name: defaultName,
      gradientIndex: 0,
      iconIndex: -1, // Monogram by default
    );

    _loadFromPrefs();

    return initialState;
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString('${_storagePrefix}_name');
      final savedGradient = prefs.getInt('${_storagePrefix}_gradient_index');
      final savedIcon = prefs.getInt('${_storagePrefix}_icon_index');

      if (savedName != null || savedGradient != null || savedIcon != null) {
        state = ProfileState(
          name: savedName ?? state.name,
          gradientIndex: savedGradient ?? state.gradientIndex,
          iconIndex: savedIcon ?? state.iconIndex,
        );
      }
    } catch (_) {}
  }

  Future<void> updateProfile({
    required String name,
    required int gradientIndex,
    required int iconIndex,
  }) async {
    state = ProfileState(
      name: name,
      gradientIndex: gradientIndex,
      iconIndex: iconIndex,
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${_storagePrefix}_name', name);
      await prefs.setInt('${_storagePrefix}_gradient_index', gradientIndex);
      await prefs.setInt('${_storagePrefix}_icon_index', iconIndex);
    } catch (_) {}
  }
}

final profileProvider = NotifierProvider.family<ProfileNotifier, ProfileState, String?>(
  ProfileNotifier.new,
);

final activeProfileProvider = Provider<ProfileState>((ref) {
  final currentStaff = ref.watch(currentUserProfileProvider);
  if (currentStaff != null) {
    return ref.watch(profileProvider(currentStaff.id));
  } else {
    return ref.watch(profileProvider(null));
  }
});
