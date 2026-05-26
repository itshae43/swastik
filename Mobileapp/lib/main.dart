import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swastik_mobile_app/core/utils/responsive_utils.dart';
import 'package:swastik_mobile_app/core/services/notification_service.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:swastik_mobile_app/core/utils/device_identity.dart';
import 'features/auth/presentation/screens/splash_screen.dart';
import 'items_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DeviceIdentity.init();
  tz.initializeTimeZones();
  await NotificationService().init();
  runApp(const ProviderScope(child: SwarnKhataApp()));
}

class SwarnKhataApp extends StatelessWidget {
  const SwarnKhataApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Swastik',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFD4B13B)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFFF8F0),
        textTheme: GoogleFonts.montserratTextTheme(),
      ),
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        final isTablet = AppResponsive.isTablet(context);
        final textScale = AppResponsive.tabletTextScale(context);
        final appChild = child ?? const SizedBox.shrink();

        return MediaQuery(
          data: isTablet
              ? mediaQuery.copyWith(textScaler: TextScaler.linear(textScale))
              : mediaQuery,
          child: Theme(
            data: Theme.of(context).copyWith(
              visualDensity: AppResponsive.visualDensity(context),
              materialTapTargetSize: isTablet
                  ? MaterialTapTargetSize.shrinkWrap
                  : MaterialTapTargetSize.padded,
            ),
            child: appChild,
          ),
        );
      },
      home: const SplashScreen(),
    );
  }
}
