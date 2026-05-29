import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swastik_mobile_app/core/utils/responsive_utils.dart';
import 'package:swastik_mobile_app/core/services/notification_service.dart';

class NotificationsEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    _loadFromPrefs();
    return true;
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool('notifications_enabled');
      if (saved != null) {
        state = saved;
      }
    } catch (_) {}
  }

  Future<void> setValue(bool val) async {
    state = val;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', val);
      await NotificationService().repairSchedulesFromServer(force: true);
    } catch (_) {}
  }
}
final notificationsEnabledProvider = NotifierProvider<NotificationsEnabledNotifier, bool>(
  NotificationsEnabledNotifier.new,
);

class DailyRemindersEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    _loadFromPrefs();
    return true;
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool('reminders_enabled');
      if (saved != null) {
        state = saved;
      }
    } catch (_) {}
  }

  Future<void> setValue(bool val) async {
    state = val;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('reminders_enabled', val);
      await NotificationService().repairSchedulesFromServer(force: true);
    } catch (_) {}
  }
}
final dailyRemindersEnabledProvider = NotifierProvider<DailyRemindersEnabledNotifier, bool>(
  DailyRemindersEnabledNotifier.new,
);

class AppointmentsEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    _loadFromPrefs();
    return true;
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool('appointments_enabled');
      if (saved != null) {
        state = saved;
      }
    } catch (_) {}
  }

  Future<void> setValue(bool val) async {
    state = val;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('appointments_enabled', val);
      await NotificationService().repairSchedulesFromServer(force: true);
    } catch (_) {}
  }
}
final appointmentsEnabledProvider = NotifierProvider<AppointmentsEnabledNotifier, bool>(
  AppointmentsEnabledNotifier.new,
);

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTablet = AppResponsive.isTablet(context);
    final isNotificationsEnabled = ref.watch(notificationsEnabledProvider);
    final isDailyRemindersEnabled = ref.watch(dailyRemindersEnabledProvider);
    final isAppointmentsEnabled = ref.watch(appointmentsEnabledProvider);

    final primaryGold = const Color(0xFF8A7311);

    return Scaffold(
      backgroundColor: isTablet ? const Color(0xFFFAF6EE) : const Color(0xFFFDFBF7),
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: GoogleFonts.montserrat(
            fontSize: isTablet ? 22 : 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E1E1E),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 28.0 : 20.0,
            vertical: 12.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main Toggle Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
                  border: Border.all(color: Colors.grey.withOpacity(0.12)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: EdgeInsets.all(isTablet ? 20 : 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(isTablet ? 10 : 8),
                          decoration: BoxDecoration(
                            color: isNotificationsEnabled
                                ? const Color(0xFFFFF3D0)
                                : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            isNotificationsEnabled
                                ? Icons.notifications_active_rounded
                                : Icons.notifications_off_rounded,
                            color: isNotificationsEnabled ? primaryGold : Colors.grey,
                            size: isTablet ? 24 : 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'All Notifications',
                              style: GoogleFonts.montserrat(
                                fontSize: isTablet ? 16 : 15,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1E1E1E),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isNotificationsEnabled ? 'Enabled' : 'Disabled',
                              style: GoogleFonts.montserrat(
                                fontSize: isTablet ? 12 : 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Switch.adaptive(
                      value: isNotificationsEnabled,
                      activeColor: primaryGold,
                      onChanged: (value) {
                        ref.read(notificationsEnabledProvider.notifier).setValue(value);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              if (isNotificationsEnabled) ...[
                Text(
                  'PREFERENCES',
                  style: GoogleFonts.montserrat(
                    fontSize: isTablet ? 12 : 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[500],
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                _buildToggleCard(
                  title: 'Reminders',
                  subtitle: 'Daily updates and collection alerts',
                  value: isDailyRemindersEnabled,
                  icon: Icons.notifications_none_outlined,
                  onChanged: (val) {
                    ref.read(dailyRemindersEnabledProvider.notifier).setValue(val);
                  },
                  isTablet: isTablet,
                  primaryGold: primaryGold,
                ),
                _buildToggleCard(
                  title: 'Appointments',
                  subtitle: 'Upcoming sessions and schedule alerts',
                  value: isAppointmentsEnabled,
                  icon: Icons.calendar_today_outlined,
                  onChanged: (val) {
                    ref.read(appointmentsEnabledProvider.notifier).setValue(val);
                  },
                  isTablet: isTablet,
                  primaryGold: primaryGold,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleCard({
    required String title,
    required String subtitle,
    required bool value,
    required IconData icon,
    required ValueChanged<bool> onChanged,
    required bool isTablet,
    required Color primaryGold,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: isTablet ? 12 : 10),
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 18 : 16,
        vertical: isTablet ? 16 : 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isTablet ? 18 : 14),
        border: Border.all(color: Colors.grey.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isTablet ? 10 : 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3D0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: primaryGold,
              size: isTablet ? 22 : 18,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.montserrat(
                    fontSize: isTablet ? 16 : 15,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF1E1E1E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.montserrat(
                    fontSize: isTablet ? 12 : 11,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeColor: primaryGold,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
