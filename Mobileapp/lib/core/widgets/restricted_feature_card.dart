import 'package:flutter/material.dart';

class RestrictedFeatureCard extends StatelessWidget {
  final bool isStaff;
  final Widget child;
  final AlignmentGeometry lockAlignment;
  final EdgeInsetsGeometry lockPadding;
  final double lockIconSize;
  final double containerSize;

  const RestrictedFeatureCard({
    super.key,
    required this.isStaff,
    required this.child,
    this.lockAlignment = Alignment.topRight,
    this.lockPadding = const EdgeInsets.all(4.0),
    this.lockIconSize = 12.0,
    this.containerSize = 20.0,
  });

  @override
  Widget build(BuildContext context) {
    if (!isStaff) {
      return child;
    }
    return _LockedFeatureWrapper(
      lockAlignment: lockAlignment,
      lockPadding: lockPadding,
      lockIconSize: lockIconSize,
      containerSize: containerSize,
      child: child,
    );
  }
}

class _LockedFeatureWrapper extends StatefulWidget {
  final Widget child;
  final AlignmentGeometry lockAlignment;
  final EdgeInsetsGeometry lockPadding;
  final double lockIconSize;
  final double containerSize;

  const _LockedFeatureWrapper({
    required this.child,
    required this.lockAlignment,
    required this.lockPadding,
    required this.lockIconSize,
    required this.containerSize,
  });

  @override
  State<_LockedFeatureWrapper> createState() => _LockedFeatureWrapperState();
}

class _LockedFeatureWrapperState extends State<_LockedFeatureWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.3)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.3, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 50,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _triggerPulse() {
    if (_controller.isAnimating) return;
    _controller.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _triggerPulse,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Opacity(
            opacity: 0.75,
            child: IgnorePointer(
              ignoring: true,
              child: widget.child,
            ),
          ),
          Positioned.fill(
            child: Align(
              alignment: widget.lockAlignment,
              child: Padding(
                padding: widget.lockPadding,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    width: widget.containerSize,
                    height: widget.containerSize,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3D0), // Soft cream/gold
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFD4B13B).withValues(alpha: 0.6),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 3,
                          offset: const Offset(0, 1.5),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.lock_rounded,
                        size: widget.lockIconSize,
                        color: const Color(0xFF8A7311), // Rich mustard gold
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

