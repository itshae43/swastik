import 'package:flutter/material.dart';

class AppResponsive {
  const AppResponsive._();

  static const double tabletMinWidth = 600;
  static const double tabletMaxLongestSide = 1366;

  static bool isTablet(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return size.shortestSide >= tabletMinWidth &&
        size.longestSide <= tabletMaxLongestSide;
  }

  static bool isTabletLandscape(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return isTablet(context) && size.width > size.height;
  }

  static double tabletTextScale(BuildContext context) {
    if (!isTablet(context)) return 1;
    return isTabletLandscape(context) ? 0.96 : 0.98;
  }

  static VisualDensity visualDensity(BuildContext context) {
    return isTablet(context)
        ? const VisualDensity(horizontal: -0.5, vertical: -0.5)
        : VisualDensity.standard;
  }
}
