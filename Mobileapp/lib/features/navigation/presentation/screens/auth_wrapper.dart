import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
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

    if (authState == AuthStatus.initial || authState == AuthStatus.loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF13331E),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(Color(0xFFD4B13B)),
          ),
        ),
      );
    }

    // Unverified or Error state -> Show Verify Screen
    return Scaffold(
      backgroundColor: const Color(0xFF13331E),
      body: Stack(
        children: [
          // Background subtle gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [
                    const Color(0xFF1A472A).withOpacity(0.4),
                    const Color(0xFF07140C).withOpacity(0.95),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF13331E).withOpacity(0.6),
                        border: Border.all(
                          color: const Color(0xFFD4B13B).withOpacity(0.8),
                          width: 2.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFD4B13B).withOpacity(0.2),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Image.asset(
                            'assets/images/logo.png',
                            width: 80,
                            height: 80,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.diamond_outlined,
                              color: Color(0xFFD4B13B),
                              size: 56,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'DEVICE VERIFICATION',
                      style: GoogleFonts.cinzel(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFD4B13B),
                        letterSpacing: 2.0,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Your device is currently not authorized or logged out. Please verify your device to access the ledger.',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Colors.white70,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          ref.read(authStateProvider.notifier).verify();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD4B13B),
                          foregroundColor: const Color(0xFF13331E),
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Verify Device',
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                    if (authState == AuthStatus.error) ...[
                      const SizedBox(height: 24),
                      Text(
                        'Unable to reach server. Check connection.',
                        style: GoogleFonts.montserrat(
                          color: Colors.redAccent,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if (authState == AuthStatus.unverified) ...[
                      const SizedBox(height: 24),
                      Text(
                        'Unauthorized Device',
                        style: GoogleFonts.montserrat(
                          color: Colors.redAccent,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
