import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swastik_mobile_app/core/services/notification_service.dart';
import 'package:swastik_mobile_app/core/utils/responsive_utils.dart';
import 'package:swastik_mobile_app/features/reminders/providers/reminder_navigation_provider.dart';

import '../../../home/presentation/screens/home_screen.dart';
import '../../../entries/presentation/screens/entries_screen.dart';
import '../../../ledger/presentation/screens/ledger_screen.dart';
import '../../../reminders/presentation/screens/reminders_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../providers/navigation_provider.dart';
import '../widgets/custom_bottom_nav_bar.dart';
import '../widgets/collapsible_sidebar.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  late final NotificationNavigationHandler _notificationNavigationHandler;
  bool _isSidebarCollapsed = false;

  // Persistent GlobalKey to reparent the bodyContent smoothly on orientation change
  final GlobalKey _bodyKey = GlobalKey(debugLabel: 'main_body_content_key');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notificationNavigationHandler = _handleNotificationNavigation;
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _scaleAnimation = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0.0, 0.02), end: Offset.zero).animate(
          CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic),
        );
    _fadeController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      NotificationService().setNavigationHandler(
        _notificationNavigationHandler,
      );
      NotificationService().repairSchedulesFromServer(force: true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NotificationService().clearNavigationHandler(
      _notificationNavigationHandler,
    );
    _fadeController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      NotificationService().repairSchedulesFromServer(force: true);
    }
  }

  void _handleNotificationNavigation(NotificationNavigationTarget target) {
    ref.read(navigationProvider.notifier).setIndex(3);

    final reminderNavigation = ref.read(reminderNavigationProvider.notifier);
    switch (target.type) {
      case NotificationNavigationType.reminder:
        reminderNavigation.showReminders(filter: 'All');
        break;
      case NotificationNavigationType.appointment:
        reminderNavigation.showAppointments(filter: 'All');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(navigationProvider);
    ref.listen<int>(navigationProvider, (previous, next) {
      if (previous != next) {
        _fadeController.forward(from: 0.0);
      }
    });
    final isTablet = AppResponsive.isTablet(context);
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final showSidebar = isTablet && isLandscape;

    Widget bodyContent = FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: IndexedStack(
            key: _bodyKey,
            index: currentIndex,
            children: const [
              HomeScreen(),
              EntriesScreen(),
              LedgerScreen(),
              RemindersScreen(),
              SettingsScreen(),
            ],
          ),
        ),
      ),
    );

    if (showSidebar) {
      bodyContent = Row(
        children: [
          CollapsibleSidebar(
            currentIndex: currentIndex,
            onTap: (index) {
              ref.read(navigationProvider.notifier).setIndex(index);
            },
            isCollapsed: _isSidebarCollapsed,
            onToggleCollapse: () {
              setState(() {
                _isSidebarCollapsed = !_isSidebarCollapsed;
              });
            },
          ),
          Expanded(child: bodyContent),
        ],
      );
    }

    return Scaffold(
      backgroundColor: isTablet
          ? const Color(0xFFFAF6EE)
          : const Color(0xFFFDFBF7),
      body: bodyContent,
      bottomNavigationBar: showSidebar ? null : const CustomBottomNavBar(),
    );
  }
}
