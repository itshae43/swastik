import 'package:flutter/material.dart';

class RestrictedFeatureCard extends StatefulWidget {
  final bool isStaff;
  final Widget child;

  const RestrictedFeatureCard({
    super.key,
    required this.isStaff,
    required this.child,
  });

  @override
  State<RestrictedFeatureCard> createState() => _RestrictedFeatureCardState();
}

class _RestrictedFeatureCardState extends State<RestrictedFeatureCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _glowAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _triggerGlow() {
    if (_controller.isAnimating) return;
    _controller.forward(from: 0.0).then((_) {
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) {
          _controller.reverse();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isStaff) {
      return widget.child;
    }

    final colorTween = ColorTween(
      begin: const Color(0xFF9E9E9E), // subtle iOS gray
      end: const Color(0xFFFFB300),   // premium amber/gold glow
    ).animate(_glowAnimation);

    final scaleTween = Tween<double>(
      begin: 1.0,
      end: 1.25,
    ).animate(_glowAnimation);

    final glowSizeTween = Tween<double>(
      begin: 0.0,
      end: 14.0,
    ).animate(_glowAnimation);

    final glowOpacityTween = Tween<double>(
      begin: 0.0,
      end: 0.8,
    ).animate(_glowAnimation);

    return GestureDetector(
      onTap: _triggerGlow,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: 0.6,
            child: IgnorePointer(
              ignoring: true,
              child: widget.child,
            ),
          ),
          AnimatedBuilder(
            animation: _glowAnimation,
            builder: (context, child) {
              final color = colorTween.value;
              final scale = scaleTween.value;
              final glowSize = glowSizeTween.value;
              final glowOpacity = glowOpacityTween.value;

              return Transform.scale(
                scale: scale,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      if (glowSize > 0.1)
                        BoxShadow(
                          color: const Color(0xFFFFB300).withOpacity(glowOpacity),
                          blurRadius: glowSize,
                          spreadRadius: glowSize / 3,
                        ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.lock_rounded,
                    size: 14,
                    color: color,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
