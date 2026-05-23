import 'package:flutter/material.dart';

class AvatarHelper {
  static const List<List<Color>> gradients = [
    [Color(0xFFD4B13B), Color(0xFF8A7311)], // Golden Swastik default
    [Color(0xFF0F9B0F), Color(0xFF075E07)], // Emerald Green
    [Color(0xFF2979FF), Color(0xFF1565C0)], // Royal Blue
    [Color(0xFFE91E63), Color(0xFFAD1457)], // Ruby Red
    [Color(0xFF00BFA5), Color(0xFF00695C)], // Teal Jewel
    [Color(0xFFFF9100), Color(0xFFFF6D00)], // Sunset Orange
  ];

  static const List<IconData> icons = [
    Icons.workspace_premium_rounded, // Crown/Premium
    Icons.diamond_outlined,          // Diamond
    Icons.storefront_rounded,        // Store/Business
    Icons.star_rounded,              // Star
    Icons.person_rounded,            // User
    Icons.pets_rounded,              // Paw/Fun
  ];
}

class UserAvatar extends StatelessWidget {
  final String name;
  final int gradientIndex;
  final int iconIndex;
  final double size;
  final double fontSize;
  final double iconSize;

  const UserAvatar({
    super.key,
    required this.name,
    required this.gradientIndex,
    required this.iconIndex,
    required this.size,
    this.fontSize = 24,
    this.iconSize = 28,
  });

  @override
  Widget build(BuildContext context) {
    final gradientColors = AvatarHelper.gradients[
      gradientIndex >= 0 && gradientIndex < AvatarHelper.gradients.length
          ? gradientIndex
          : 0
    ];

    Widget avatarContent;
    if (iconIndex >= 0 && iconIndex < AvatarHelper.icons.length) {
      avatarContent = Icon(
        AvatarHelper.icons[iconIndex],
        color: Colors.white,
        size: iconSize,
      );
    } else {
      // Monogram
      final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
      avatarContent = Text(
        initial,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontFamily: 'Montserrat',
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: avatarContent,
    );
  }
}
