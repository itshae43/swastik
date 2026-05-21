import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swastik_mobile_app/features/auth/providers/auth_providers.dart';
import 'package:swastik_mobile_app/features/navigation/presentation/screens/auth_wrapper.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {

  // ── Entrance controller ──
  late AnimationController _entranceController;
  late Animation<double> _bgScale;
  late Animation<double> _bgOpacity;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textOpacity;
  late Animation<double> _textSlideY;
  late Animation<double> _loaderOpacity;

  // ── Continuous glow pulse ──
  late AnimationController _pulseController;
  late Animation<double> _pulseGlow;
  late Animation<double> _pulseRingAlpha;

  // ── Shimmer sweep on ring ──
  late AnimationController _shimmerController;
  late Animation<double> _shimmerProgress;

  bool _timerFinished = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    // ── Entrance: 2.2 seconds ──
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    // Background fades in after a delay to match the "illustration come in motion"
    _bgOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.20, 0.55, curve: Curves.easeIn),
      ),
    );

    _bgScale = Tween<double>(begin: 1.14, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.20, 0.80, curve: Curves.easeOutSine),
      ),
    );

    // Logo is fully visible from start to provide a seamless transition from native splash
    _logoOpacity = Tween<double>(begin: 1.0, end: 1.0).animate(_entranceController);
    _logoScale = Tween<double>(begin: 1.0, end: 1.0).animate(_entranceController);

    // Text fades in below logo
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.40, 0.80, curve: Curves.easeOut),
      ),
    );

    _textSlideY = Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.40, 0.80, curve: Curves.easeOut),
      ),
    );

    _loaderOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.75, 1.0, curve: Curves.easeIn),
      ),
    );

    // ── Pulse glow: 2.4s loop ──
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _pulseGlow = Tween<double>(begin: 16.0, end: 58.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _pulseRingAlpha = Tween<double>(begin: 0.45, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // ── Shimmer sweep: 1.8s loop ──
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _shimmerProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.linear),
    );

    _entranceController.forward();

    // Hold until minimum display time has elapsed (3.2 s total)
    Timer(const Duration(milliseconds: 3200), () {
      if (!mounted) return;
      setState(() => _timerFinished = true);
      _checkAndNavigate(ref.read(authStateProvider));
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  void _checkAndNavigate(AuthStatus authState) {
    if (_navigated) return;
    if (_timerFinished &&
        authState != AuthStatus.initial &&
        authState != AuthStatus.loading) {
      _navigated = true;
      _navigateToNext();
    }
  }

  void _navigateToNext() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, a, b) => const AuthWrapper(),
        transitionsBuilder: (_, animation, a, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 900),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _checkAndNavigate(authState),
    );

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: const Color(0xFF071A0F),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _entranceController,
          _pulseController,
          _shimmerController,
        ]),
        builder: (context, _) {
          return SizedBox.expand(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // ─── Background: Mandala illustration (full screen) ───
                Positioned.fill(
                  child: Opacity(
                    opacity: _bgOpacity.value,
                    child: Transform.scale(
                      scale: _bgScale.value,
                      child: Image.asset(
                        'assets/images/splash_bg.png',
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (_, e, s) =>
                            Container(color: const Color(0xFF071A0F)),
                      ),
                    ),
                  ),
                ),

                // ─── Vignette / dark overlay ───
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 1.35,
                        colors: [
                          Color(0x22122B1A),
                          Color(0xDE060F08),
                        ],
                      ),
                    ),
                  ),
                ),

                // ─── Content: Centered layout ───
                Positioned.fill(
                  child: SafeArea(
                    child: isLandscape
                        ? _buildLandscapeLayout()
                        : _buildPortraitLayout(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Portrait layout: Stack layout to keep logo perfectly centered
  Widget _buildPortraitLayout() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // ── Glowing logo circle (perfectly centered) ──
        Align(
          alignment: Alignment.center,
          child: Opacity(
            opacity: _logoOpacity.value,
            child: Transform.scale(
              scale: _logoScale.value,
              child: _GlowingLogo(
                pulseGlow: _pulseGlow.value,
                pulseRingAlpha: _pulseRingAlpha.value,
                shimmerProgress: _shimmerProgress.value,
              ),
            ),
          ),
        ),

        // ── Branding text ──
        Align(
          alignment: const Alignment(0.0, 0.45),
          child: Opacity(
            opacity: _textOpacity.value,
            child: Transform.translate(
              offset: Offset(0, _textSlideY.value),
              child: const _BrandingText(),
            ),
          ),
        ),

        // ── Bottom loader ──
        Align(
          alignment: const Alignment(0.0, 0.85),
          child: Opacity(
            opacity: _loaderOpacity.value,
            child: const _BottomLoader(),
          ),
        ),
      ],
    );
  }

  /// Landscape layout: Logo centered, text to the right, loader at bottom
  Widget _buildLandscapeLayout() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // ── Glowing logo circle (perfectly centered) ──
        Align(
          alignment: Alignment.center,
          child: Opacity(
            opacity: _logoOpacity.value,
            child: Transform.scale(
              scale: _logoScale.value,
              child: _GlowingLogo(
                pulseGlow: _pulseGlow.value,
                pulseRingAlpha: _pulseRingAlpha.value,
                shimmerProgress: _shimmerProgress.value,
              ),
            ),
          ),
        ),

        // ── Branding text ──
        Align(
          alignment: const Alignment(0.55, 0.0),
          child: Opacity(
            opacity: _textOpacity.value,
            child: Transform.translate(
              offset: Offset(0, _textSlideY.value),
              child: const _BrandingText(),
            ),
          ),
        ),

        // ── Bottom loader ──
        Align(
          alignment: const Alignment(0.0, 0.85),
          child: Opacity(
            opacity: _loaderOpacity.value,
            child: const _BottomLoader(),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
// Glowing logo circle widget
// ─────────────────────────────────────────────────────────
class _GlowingLogo extends StatelessWidget {
  final double pulseGlow;
  final double pulseRingAlpha;
  final double shimmerProgress;

  const _GlowingLogo({
    required this.pulseGlow,
    required this.pulseRingAlpha,
    required this.shimmerProgress,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outermost diffuse glow
        Container(
          width: 220,
          height: 220,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color.fromRGBO(212, 177, 59, pulseRingAlpha * 0.12),
                blurRadius: pulseGlow * 2.5,
                spreadRadius: pulseGlow * 0.55,
              ),
            ],
          ),
        ),

        // Mid glow halo
        Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Color.fromRGBO(212, 177, 59, pulseRingAlpha * 0.16),
                Colors.transparent,
              ],
            ),
          ),
        ),

        // Glass circle
        Container(
          width: 158,
          height: 158,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF13331E).withValues(alpha: 0.52),
            border: Border.all(
              color: Color.fromRGBO(212, 177, 59, 0.55 + 0.40 * pulseRingAlpha),
              width: 1.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Color.fromRGBO(212, 177, 59, pulseRingAlpha * 0.24),
                blurRadius: pulseGlow,
                spreadRadius: pulseGlow * 0.08,
              ),
              BoxShadow(
                color: Color.fromRGBO(212, 177, 59, pulseRingAlpha * 0.10),
                blurRadius: pulseGlow * 2.0,
                spreadRadius: pulseGlow * 0.22,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(26.0),
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.contain,
              errorBuilder: (_, e, s) => const Icon(
                Icons.diamond_outlined,
                color: Color(0xFFD4B13B),
                size: 72,
              ),
            ),
          ),
        ),

        // Shimmer sweep ring
        SizedBox(
          width: 164,
          height: 164,
          child: CustomPaint(
            painter: _ShimmerRingPainter(progress: shimmerProgress),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
// Branding text: SWASTIK + divider + JEWELS
// ─────────────────────────────────────────────────────────
class _BrandingText extends StatelessWidget {
  const _BrandingText();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // SWASTIK — Cinzel with gold gradient
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFEDD98C),
              Color(0xFFD4B13B),
              Color(0xFFF5E6A4),
              Color(0xFFD4B13B),
            ],
            stops: [0.0, 0.35, 0.65, 1.0],
          ).createShader(bounds),
          child: Text(
            'SWASTIK',
            style: GoogleFonts.cinzel(
              fontSize: 46,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 5.5,
              height: 1.0,
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Ornamental divider
        SizedBox(
          width: 200,
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 0.6,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Colors.transparent,
                      const Color(0xFFD4B13B).withValues(alpha: 0.5),
                    ]),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFD4B13B).withValues(alpha: 0.85),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD4B13B).withValues(alpha: 0.5),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  height: 0.6,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      const Color(0xFFD4B13B).withValues(alpha: 0.5),
                      Colors.transparent,
                    ]),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // JEWELS subtitle
        Text(
          'J E W E L S',
          style: GoogleFonts.cinzel(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: const Color(0xFFD4B13B).withValues(alpha: 0.75),
            letterSpacing: 8.0,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
// Bottom loading indicator
// ─────────────────────────────────────────────────────────
class _BottomLoader extends StatelessWidget {
  const _BottomLoader();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
            strokeWidth: 1.8,
            backgroundColor: const Color(0xFFD4B13B).withValues(alpha: 0.12),
            valueColor: const AlwaysStoppedAnimation(Color(0xFFD4B13B)),
            strokeCap: StrokeCap.round,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Loading secure ledger...',
          style: GoogleFonts.cinzel(
            fontSize: 9.5,
            fontWeight: FontWeight.w400,
            color: const Color(0xFFD4B13B).withValues(alpha: 0.42),
            letterSpacing: 2.5,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
// Shimmer sweep ring CustomPainter
// ─────────────────────────────────────────────────────────
class _ShimmerRingPainter extends CustomPainter {
  final double progress;
  _ShimmerRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 0.9;
    final angle = progress * 3.14159265 * 2;

    final paint = Paint()
      ..shader = SweepGradient(
        startAngle: angle - 1.0,
        endAngle: angle + 1.0,
        colors: const [
          Colors.transparent,
          Color(0x44D4B13B),
          Color(0xCCE8D08A),
          Color(0x44D4B13B),
          Colors.transparent,
        ],
        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_ShimmerRingPainter old) => old.progress != progress;
}
