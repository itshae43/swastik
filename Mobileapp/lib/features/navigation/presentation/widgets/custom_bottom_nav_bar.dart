import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swastik_mobile_app/core/utils/responsive_utils.dart';
import '../providers/navigation_provider.dart';

class CustomBottomNavBar extends ConsumerWidget {
  const CustomBottomNavBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(navigationProvider);
    final isTablet = AppResponsive.isTablet(context);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: isTablet ? 80 : 76,
          padding: EdgeInsets.symmetric(horizontal: isTablet ? 72 : 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double totalWidth = constraints.maxWidth;
              final double tabWidth = totalWidth / 5;
              final double bgSize = isTablet ? 48.0 : 45.0;
              final double fontSize = isTablet ? 13.0 : 11.0;
              final double navBarHeight = isTablet ? 80.0 : 76.0;
              final double topOffset = (navBarHeight - (bgSize + 6 + fontSize * 1.35)) / 2;
              final double leftOffset = currentIndex * tabWidth + (tabWidth - bgSize) / 2;

              return Stack(
                children: [
                  // Smooth sliding indicator
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    left: leftOffset,
                    top: topOffset,
                    width: bgSize,
                    height: bgSize,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF01565B),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF01565B).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Row of navigation items
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _NavBarItem(
                        icon: Icons.home_rounded,
                        label: isTablet ? 'Home' : 'Dashboard',
                        isSelected: currentIndex == 0,
                        isTablet: isTablet,
                        onTap: () => ref.read(navigationProvider.notifier).setIndex(0),
                      ),
                      _NavBarItem(
                        icon: Icons.add_box_rounded,
                        label: 'Entries',
                        isSelected: currentIndex == 1,
                        isTablet: isTablet,
                        onTap: () => ref.read(navigationProvider.notifier).setIndex(1),
                      ),
                      _NavBarItem(
                        icon: Icons.account_balance_wallet_rounded,
                        label: 'Ledger',
                        isSelected: currentIndex == 2,
                        isTablet: isTablet,
                        onTap: () => ref.read(navigationProvider.notifier).setIndex(2),
                      ),
                      _NavBarItem(
                        icon: Icons.notifications_active_rounded,
                        label: 'Reminders',
                        isSelected: currentIndex == 3,
                        isTablet: isTablet,
                        onTap: () => ref.read(navigationProvider.notifier).setIndex(3),
                      ),
                      _NavBarItem(
                        icon: Icons.settings_rounded,
                        label: 'Settings',
                        isSelected: currentIndex == 4,
                        isTablet: isTablet,
                        onTap: () => ref.read(navigationProvider.notifier).setIndex(4),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isTablet;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.isTablet,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double bgSize = isTablet ? 48 : 45;
    final double iconSize = isTablet ? 28 : 26;
    final double fontSize = isTablet ? 13 : 11;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: bgSize,
              height: bgSize,
              child: Center(
                child: AnimatedScale(
                  scale: isSelected ? 1.15 : 1.0,
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  child: Icon(
                    icon,
                    color: isSelected
                        ? const Color(0xFFCFA63A)
                        : const Color(0xFF4D4635).withValues(alpha: 0.6),
                    size: iconSize,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            // Label with style animation
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              style: isTablet
                  ? GoogleFonts.montserrat(
                      fontSize: fontSize,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w600,
                      color: isSelected
                          ? const Color(0xFF01565B)
                          : const Color(0xFF4D4635).withValues(alpha: 0.6),
                      letterSpacing: isSelected ? 0.3 : 0,
                    )
                  : GoogleFonts.montserrat(
                      fontSize: fontSize,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w600,
                      color: isSelected
                          ? const Color(0xFF01565B)
                          : const Color(0xFF4D4635).withValues(alpha: 0.6),
                      letterSpacing: isSelected ? 0.3 : 0,
                    ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
