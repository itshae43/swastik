import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    } catch (e) {
      state = AuthStatus.error;
    }
  }

  void logout() {
    state = AuthStatus.unverified;
  }
}

final authStateProvider = NotifierProvider<AuthNotifier, AuthStatus>(AuthNotifier.new);

