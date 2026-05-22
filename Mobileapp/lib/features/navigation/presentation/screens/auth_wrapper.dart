import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swastik_mobile_app/features/auth/presentation/screens/device_verification_screen.dart';
import 'package:swastik_mobile_app/features/auth/providers/auth_providers.dart';
import 'package:swastik_mobile_app/features/navigation/presentation/screens/main_screen.dart';

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    if (authState == AuthStatus.verified) {
      return const MainScreen();
    }

    if (authState == AuthStatus.initial) {
      return const Scaffold(
        backgroundColor: Color(0xFFFFF8F0),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(Color(0xFFD4B13B)),
          ),
        ),
      );
    }

    // Unverified, Error, or Loading (during verification trigger) -> Show Verify Screen
    return const DeviceVerificationScreen();
  }
}

