import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/appointment_model.dart';
import '../models/reminder_model.dart';
import '../utils/time_utils.dart';
import 'appointment_service.dart';
import 'reminder_service.dart';

enum NotificationNavigationType { reminder, appointment }

class NotificationNavigationTarget {
  final NotificationNavigationType type;
  final String id;
  final String? phase;

  const NotificationNavigationTarget({
    required this.type,
    required this.id,
    this.phase,
  });

  static NotificationNavigationTarget? fromPayload(String? payload) {
    if (payload == null || payload.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) return null;

      final typeValue = decoded['type'] as String?;
      final id = decoded['id']?.toString() ?? '';
      if (id.isEmpty) return null;

      return switch (typeValue) {
        'reminder' => NotificationNavigationTarget(
          type: NotificationNavigationType.reminder,
          id: id,
          phase: decoded['phase'] as String?,
        ),
        'appointment' => NotificationNavigationTarget(
          type: NotificationNavigationType.appointment,
          id: id,
          phase: decoded['phase'] as String?,
        ),
        _ => null,
      };
    } catch (_) {
      return null;
    }
  }
}

typedef NotificationNavigationHandler =
    void Function(NotificationNavigationTarget target);

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const String _smallIcon = 'ic_stat_swastik';
  static const String _largeIcon = 'ic_notification_large';
  static const int _reminderBand = 100000000;
  static const int _appointmentDueBand = 200000000;
  static const int _appointmentBeforeBand = 300000000;
  static const int _bandSize = 90000000;

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _exactAlarmRequestAttempted = false;
  String? _lastReminderSignature;
  String? _lastAppointmentSignature;
  Future<void>? _serverRepairInFlight;
  NotificationNavigationHandler? _navigationHandler;
  NotificationNavigationTarget? _pendingNavigationTarget;

  Future<void> init() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings(_smallIcon);
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );
    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await _flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );

    final launchDetails = await _flutterLocalNotificationsPlugin
        .getNotificationAppLaunchDetails();
    final launchResponse = launchDetails?.notificationResponse;
    if (launchDetails?.didNotificationLaunchApp == true &&
        launchResponse != null) {
      _routeNotificationPayload(launchResponse.payload);
    }

    if (Platform.isAndroid) {
      await _androidImplementation()?.requestNotificationsPermission();
    }
  }

  void setNavigationHandler(NotificationNavigationHandler handler) {
    _navigationHandler = handler;

    final pending = _pendingNavigationTarget;
    if (pending != null) {
      _pendingNavigationTarget = null;
      handler(pending);
    }
  }

  void clearNavigationHandler(NotificationNavigationHandler handler) {
    if (identical(_navigationHandler, handler)) {
      _navigationHandler = null;
    }
  }

  Future<void> repairSchedulesFromServer({bool force = false}) async {
    final inFlight = _serverRepairInFlight;
    if (inFlight != null) return inFlight;

    final repair = _repairSchedulesFromServer(force: force);
    _serverRepairInFlight = repair;
    try {
      await repair;
    } finally {
      _serverRepairInFlight = null;
    }
  }

  Future<void> repairReminderSchedules(
    List<ReminderModel> reminders, {
    bool force = false,
  }) async {
    final futureReminders = reminders.where(_shouldScheduleReminder).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    final signature = _buildReminderSignature(futureReminders);

    if (!force && signature == _lastReminderSignature) return;
    _lastReminderSignature = signature;

    await _cancelManagedRequests(_ManagedNotificationType.reminder);
    final scheduleMode = await _resolveAndroidScheduleMode();

    for (final reminder in futureReminders) {
      await _scheduleReminderNotification(reminder, scheduleMode);
    }
  }

  Future<void> repairAppointmentSchedules(
    List<AppointmentModel> appointments, {
    bool force = false,
  }) async {
    final futureAppointments =
        appointments.where(_shouldScheduleAppointment).toList()
          ..sort((a, b) => a.id.compareTo(b.id));
    final signature = _buildAppointmentSignature(futureAppointments);

    if (!force && signature == _lastAppointmentSignature) return;
    _lastAppointmentSignature = signature;

    await _cancelManagedRequests(_ManagedNotificationType.appointment);
    final scheduleMode = await _resolveAndroidScheduleMode();

    for (final appointment in futureAppointments) {
      await _scheduleAppointmentNotification(appointment, scheduleMode);
    }
  }

  Future<void> scheduleReminderNotification(ReminderModel reminder) async {
    if (!_shouldScheduleReminder(reminder)) return;
    final scheduleMode = await _resolveAndroidScheduleMode();
    await _scheduleReminderNotification(reminder, scheduleMode);
  }

  Future<void> cancelReminderNotification(String id) async {
    if (id.isEmpty) return;
    await _flutterLocalNotificationsPlugin.cancel(
      id: _reminderNotificationId(id),
    );
  }

  Future<void> scheduleAppointmentNotification(
    AppointmentModel appointment,
  ) async {
    if (!_shouldScheduleAppointment(appointment)) return;
    final scheduleMode = await _resolveAndroidScheduleMode();
    await _scheduleAppointmentNotification(appointment, scheduleMode);
  }

  Future<void> cancelAppointmentNotification(String id) async {
    if (id.isEmpty) return;
    await _flutterLocalNotificationsPlugin.cancel(
      id: _appointmentDueNotificationId(id),
    );
    await _flutterLocalNotificationsPlugin.cancel(
      id: _appointmentBeforeNotificationId(id),
    );
  }

  Future<void> _repairSchedulesFromServer({required bool force}) async {
    try {
      final results = await Future.wait([
        ReminderService().fetchReminders(),
        AppointmentService().fetchAppointments(),
      ]);

      await repairReminderSchedules(
        results[0] as List<ReminderModel>,
        force: force,
      );
      await repairAppointmentSchedules(
        results[1] as List<AppointmentModel>,
        force: force,
      );
    } catch (e, st) {
      debugPrint('[NotificationService] Schedule repair failed: $e');
      debugPrint('$st');
    }
  }

  Future<AndroidScheduleMode> _resolveAndroidScheduleMode() async {
    if (!Platform.isAndroid) return AndroidScheduleMode.exactAllowWhileIdle;

    final android = _androidImplementation();
    if (android == null) return AndroidScheduleMode.inexactAllowWhileIdle;

    try {
      await android.requestNotificationsPermission();

      final canScheduleExact =
          await android.canScheduleExactNotifications() ?? true;
      if (canScheduleExact) return AndroidScheduleMode.exactAllowWhileIdle;

      if (!_exactAlarmRequestAttempted) {
        _exactAlarmRequestAttempted = true;
        await android.requestExactAlarmsPermission();
      }

      final canScheduleAfterRequest =
          await android.canScheduleExactNotifications() ?? false;
      if (canScheduleAfterRequest) {
        return AndroidScheduleMode.exactAllowWhileIdle;
      }
    } catch (e) {
      debugPrint(
        '[NotificationService] Exact alarm permission check failed: $e',
      );
    }

    return AndroidScheduleMode.inexactAllowWhileIdle;
  }

  Future<void> _scheduleReminderNotification(
    ReminderModel reminder,
    AndroidScheduleMode scheduleMode,
  ) async {
    if (reminder.id.isEmpty) return;

    final scheduledDate = _toScheduledKolkata(reminder.date);
    if (!scheduledDate.isAfter(_nowKolkata())) return;

    final body = _reminderBody(reminder);
    final notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'reminder_channel',
        'Reminders',
        channelDescription: 'Reminder notifications',
        importance: Importance.max,
        priority: Priority.high,
        icon: _smallIcon,
        largeIcon: const DrawableResourceAndroidBitmap(_largeIcon),
        color: const Color(0xFF174D2A),
        category: AndroidNotificationCategory.reminder,
        styleInformation: BigTextStyleInformation(body),
        visibility: NotificationVisibility.private,
      ),
    );

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id: _reminderNotificationId(reminder.id),
      title: 'Reminder',
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: notificationDetails,
      androidScheduleMode: scheduleMode,
      payload: _payload(
        type: NotificationNavigationType.reminder,
        id: reminder.id,
      ),
    );
  }

  Future<void> _scheduleAppointmentNotification(
    AppointmentModel appointment,
    AndroidScheduleMode scheduleMode,
  ) async {
    if (appointment.id.isEmpty) return;

    final appointmentDate = _toScheduledKolkata(appointment.date);
    if (appointmentDate.isAfter(_nowKolkata())) {
      final body = _appointmentBody(appointment);
      final notificationDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          'appointment_channel',
          'Appointments',
          channelDescription: 'Appointment notifications',
          importance: Importance.max,
          priority: Priority.high,
          icon: _smallIcon,
          largeIcon: const DrawableResourceAndroidBitmap(_largeIcon),
          color: const Color(0xFF174D2A),
          category: AndroidNotificationCategory.event,
          styleInformation: BigTextStyleInformation(body),
          visibility: NotificationVisibility.private,
        ),
      );

      await _flutterLocalNotificationsPlugin.zonedSchedule(
        id: _appointmentDueNotificationId(appointment.id),
        title: 'Appointment',
        body: body,
        scheduledDate: appointmentDate,
        notificationDetails: notificationDetails,
        androidScheduleMode: scheduleMode,
        payload: _payload(
          type: NotificationNavigationType.appointment,
          id: appointment.id,
          phase: 'due',
        ),
      );
    }

    final tz.TZDateTime reminderDate;
    final String body;
    final String phase;

    if (appointment.remindBefore) {
      final oneDayBefore = TimeUtils.toRealWorld(appointment.date).subtract(const Duration(days: 1));
      reminderDate = tz.TZDateTime(
        _kolkata,
        oneDayBefore.year,
        oneDayBefore.month,
        oneDayBefore.day,
        11,
        40,
      );
      body = _appointmentBeforeBody(appointment);
      phase = 'one_day_before';
    } else {
      final createdRealDate = TimeUtils.toRealWorld(appointment.createdAt);
      reminderDate = tz.TZDateTime(
        _kolkata,
        createdRealDate.year,
        createdRealDate.month,
        createdRealDate.day,
        11,
        40,
      );
      body = _appointmentCreatedDayBody(appointment);
      phase = 'created_day';
    }

    if (!reminderDate.isAfter(_nowKolkata())) return;

    final notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'appointment_channel',
        'Appointments',
        channelDescription: 'Appointment notifications',
        importance: Importance.max,
        priority: Priority.high,
        icon: _smallIcon,
        largeIcon: const DrawableResourceAndroidBitmap(_largeIcon),
        color: const Color(0xFF174D2A),
        category: AndroidNotificationCategory.reminder,
        styleInformation: BigTextStyleInformation(body),
        visibility: NotificationVisibility.private,
      ),
    );

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id: _appointmentBeforeNotificationId(appointment.id),
      title: 'Appointment Reminder',
      body: body,
      scheduledDate: reminderDate,
      notificationDetails: notificationDetails,
      androidScheduleMode: scheduleMode,
      payload: _payload(
        type: NotificationNavigationType.appointment,
        id: appointment.id,
        phase: phase,
      ),
    );
  }

  Future<void> _cancelManagedRequests(_ManagedNotificationType type) async {
    final pending = await _flutterLocalNotificationsPlugin
        .pendingNotificationRequests();

    for (final request in pending) {
      if (_managedRequestType(request) == type) {
        await _flutterLocalNotificationsPlugin.cancel(id: request.id);
      }
    }
  }

  _ManagedNotificationType? _managedRequestType(
    PendingNotificationRequest request,
  ) {
    final target = NotificationNavigationTarget.fromPayload(request.payload);
    if (target != null) {
      return switch (target.type) {
        NotificationNavigationType.reminder =>
          _ManagedNotificationType.reminder,
        NotificationNavigationType.appointment =>
          _ManagedNotificationType.appointment,
      };
    }

    final title = request.title ?? '';
    if (title.startsWith('Reminder:') || title == 'Reminder') {
      return _ManagedNotificationType.reminder;
    }
    if (title.startsWith('Appointment:') ||
        title.startsWith('Upcoming Appointment:') ||
        title == 'Appointment' ||
        title == 'Appointment Reminder') {
      return _ManagedNotificationType.appointment;
    }
    return null;
  }

  void _handleNotificationResponse(NotificationResponse response) {
    _routeNotificationPayload(response.payload);
  }

  void _routeNotificationPayload(String? payload) {
    final target = NotificationNavigationTarget.fromPayload(payload);
    if (target == null) return;

    final handler = _navigationHandler;
    if (handler == null) {
      _pendingNavigationTarget = target;
      return;
    }

    handler(target);
  }

  AndroidFlutterLocalNotificationsPlugin? _androidImplementation() {
    return _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
  }

  bool _shouldScheduleReminder(ReminderModel reminder) {
    return reminder.id.isNotEmpty &&
        reminder.status == ReminderStatus.upcoming &&
        _toScheduledKolkata(reminder.date).isAfter(_nowKolkata());
  }

  bool _shouldScheduleAppointment(AppointmentModel appointment) {
    return appointment.id.isNotEmpty &&
        appointment.status == AppointmentStatus.upcoming &&
        _toScheduledKolkata(appointment.date).isAfter(_nowKolkata());
  }

  String _buildReminderSignature(List<ReminderModel> reminders) {
    return reminders
        .map(
          (r) => [
            r.id,
            r.date.toUtc().toIso8601String(),
            r.status.name,
            r.partyName,
            r.partyPhone,
            r.title,
            r.note,
          ].join('\u001f'),
        )
        .join('\u001e');
  }

  String _buildAppointmentSignature(List<AppointmentModel> appointments) {
    return appointments
        .map(
          (a) => [
            a.id,
            a.date.toUtc().toIso8601String(),
            a.status.name,
            a.remindBefore.toString(),
            a.customerName,
            a.phoneNumber,
            a.notes,
          ].join('\u001f'),
        )
        .join('\u001e');
  }

  String _payload({
    required NotificationNavigationType type,
    required String id,
    String? phase,
  }) {
    final payload = <String, Object?>{
      'type': switch (type) {
        NotificationNavigationType.reminder => 'reminder',
        NotificationNavigationType.appointment => 'appointment',
      },
      'id': id,
    };
    if (phase != null) {
      payload['phase'] = phase;
    }
    return jsonEncode(payload);
  }

  String _reminderBody(ReminderModel reminder) {
    final note = reminder.note.trim().isNotEmpty
        ? reminder.note.trim()
        : reminder.title.trim();
    return [
      if (reminder.partyName.trim().isNotEmpty)
        'Customer: ${reminder.partyName.trim()}',
      if (reminder.partyPhone.trim().isNotEmpty) reminder.partyPhone.trim(),
      if (note.isNotEmpty) 'Note: $note',
    ].join('\n');
  }

  String _appointmentBody(AppointmentModel appointment) {
    final when = _relativeDateTime(appointment.date);
    return [
      appointment.customerName.trim().isNotEmpty
          ? appointment.customerName.trim()
          : 'Appointment',
      when,
      if (appointment.notes.trim().isNotEmpty) appointment.notes.trim(),
    ].join('\n');
  }

  String _appointmentBeforeBody(AppointmentModel appointment) {
    final time = DateFormat(
      'h:mm a',
    ).format(TimeUtils.toRealWorld(appointment.date));
    return [
      appointment.customerName.trim().isNotEmpty
          ? appointment.customerName.trim()
          : 'Appointment',
      'Tomorrow • $time',
      if (appointment.notes.trim().isNotEmpty) appointment.notes.trim(),
    ].join('\n');
  }

  String _appointmentCreatedDayBody(AppointmentModel appointment) {
    final realDate = TimeUtils.toRealWorld(appointment.date);
    final time = DateFormat('h:mm a').format(realDate);
    final dateStr = DateFormat('dd MMM').format(realDate);
    return [
      appointment.customerName.trim().isNotEmpty
          ? appointment.customerName.trim()
          : 'Appointment',
      'Scheduled for $dateStr • $time',
      if (appointment.notes.trim().isNotEmpty) appointment.notes.trim(),
    ].join('\n');
  }

  String _relativeDateTime(DateTime date) {
    final realDate = TimeUtils.toRealWorld(date);
    final realNow = TimeUtils.toRealWorld(TimeUtils.now);
    final today = DateTime(realNow.year, realNow.month, realNow.day);
    final dateOnly = DateTime(realDate.year, realDate.month, realDate.day);
    final time = DateFormat('h:mm a').format(realDate);

    if (dateOnly == today) return 'Today • $time';
    if (dateOnly == today.add(const Duration(days: 1))) {
      return 'Tomorrow • $time';
    }

    return '${DateFormat('dd MMM').format(realDate)} • $time';
  }

  tz.TZDateTime _toScheduledKolkata(DateTime date) {
    return tz.TZDateTime.from(TimeUtils.toRealWorld(date), _kolkata);
  }

  tz.TZDateTime _nowKolkata() {
    return tz.TZDateTime.from(TimeUtils.toRealWorld(TimeUtils.now), _kolkata);
  }

  tz.Location get _kolkata => tz.getLocation('Asia/Kolkata');

  int _reminderNotificationId(String id) {
    return _stableNotificationId(id, _reminderBand);
  }

  int _appointmentDueNotificationId(String id) {
    return _stableNotificationId(id, _appointmentDueBand);
  }

  int _appointmentBeforeNotificationId(String id) {
    return _stableNotificationId(id, _appointmentBeforeBand);
  }

  int _stableNotificationId(String value, int band) {
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode(value)) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return band + (hash % _bandSize);
  }
}

enum _ManagedNotificationType { reminder, appointment }
