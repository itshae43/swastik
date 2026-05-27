import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/reminder_model.dart';
import '../models/appointment_model.dart';
import '../utils/time_utils.dart';
import 'dart:io';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse notificationResponse) async {
        // Handle notification tapped logic here
      },
    );

    if (Platform.isAndroid) {
      _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  Future<void> scheduleReminderNotification(ReminderModel reminder) async {
    final kolkata = tz.getLocation('Asia/Kolkata');
    final realDate = TimeUtils.toRealWorld(reminder.date);
    final scheduledDate = tz.TZDateTime.from(realDate, kolkata);

    if (scheduledDate.isBefore(tz.TZDateTime.now(kolkata))) return;

    const AndroidNotificationDetails androidNotificationDetails = AndroidNotificationDetails(
      'reminder_channel',
      'Reminders',
      channelDescription: 'Channel for reminder notifications',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const NotificationDetails notificationDetails = NotificationDetails(android: androidNotificationDetails);

    int notificationId = reminder.id.hashCode;

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id: notificationId,
      title: 'Reminder: ${reminder.title}',
      body: reminder.note.isNotEmpty ? reminder.note : 'You have a reminder for ${reminder.partyName}',
      scheduledDate: scheduledDate,
      notificationDetails: notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> cancelReminderNotification(String id) async {
    await _flutterLocalNotificationsPlugin.cancel(id: id.hashCode);
  }

  Future<void> scheduleAppointmentNotification(AppointmentModel appointment) async {
    final kolkata = tz.getLocation('Asia/Kolkata');
    
    // 1. Notification at appointment time
    final realDate = TimeUtils.toRealWorld(appointment.date);
    final scheduledDate = tz.TZDateTime.from(realDate, kolkata);

    if (scheduledDate.isAfter(tz.TZDateTime.now(kolkata))) {
      const AndroidNotificationDetails androidNotificationDetails = AndroidNotificationDetails(
        'appointment_channel',
        'Appointments',
        channelDescription: 'Channel for appointment notifications',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );
      const NotificationDetails notificationDetails = NotificationDetails(android: androidNotificationDetails);

      int notificationId = appointment.id.hashCode;

      await _flutterLocalNotificationsPlugin.zonedSchedule(
        id: notificationId,
        title: 'Appointment: ${appointment.customerName}',
        body: appointment.notes.isNotEmpty ? appointment.notes : 'You have an appointment with ${appointment.customerName}',
        scheduledDate: scheduledDate,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }

    // 2. Notification 1 day before (if toggled)
    if (appointment.remindBefore) {
      final oneDayBeforeDate = realDate.subtract(const Duration(days: 1));
      final scheduledDateOneDayBefore = tz.TZDateTime.from(oneDayBeforeDate, kolkata);

      if (scheduledDateOneDayBefore.isAfter(tz.TZDateTime.now(kolkata))) {
        const AndroidNotificationDetails androidNotificationDetails = AndroidNotificationDetails(
          'appointment_channel',
          'Appointments',
          channelDescription: 'Channel for appointment notifications',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        );
        const NotificationDetails notificationDetails = NotificationDetails(android: androidNotificationDetails);

        int notificationIdOneDayBefore = appointment.id.hashCode + 1;

        await _flutterLocalNotificationsPlugin.zonedSchedule(
          id: notificationIdOneDayBefore,
          title: 'Upcoming Appointment: ${appointment.customerName} Tomorrow',
          body: 'Appointment scheduled for tomorrow at ${TimeUtils.toRealWorld(appointment.date).hour}:${TimeUtils.toRealWorld(appointment.date).minute.toString().padLeft(2, "0")}',
          scheduledDate: scheduledDateOneDayBefore,
          notificationDetails: notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      }
    }
  }

  Future<void> cancelAppointmentNotification(String id) async {
    await _flutterLocalNotificationsPlugin.cancel(id: id.hashCode);
    await _flutterLocalNotificationsPlugin.cancel(id: id.hashCode + 1);
  }
}
