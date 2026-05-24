import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swastik_mobile_app/core/models/reminder_model.dart';
import 'package:swastik_mobile_app/core/services/reminder_service.dart';
import 'package:swastik_mobile_app/core/services/notification_service.dart';
import 'package:swastik_mobile_app/features/auth/providers/auth_providers.dart';
import 'package:swastik_mobile_app/core/utils/constants.dart';
import 'package:swastik_mobile_app/core/utils/time_utils.dart';

final reminderServiceProvider = Provider((ref) => ReminderService());

final Set<String> _scheduledReminders = {};

final remindersStreamProvider = StreamProvider<List<ReminderModel>>((ref) {
  return ref.watch(reminderServiceProvider).getReminders(AppConstants.centralDbId).map((reminders) {
    for (var r in reminders) {
      if (!_scheduledReminders.contains(r.id) && r.status == ReminderStatus.upcoming && r.date.isAfter(TimeUtils.now)) {
        NotificationService().scheduleReminderNotification(r);
        _scheduledReminders.add(r.id);
      }
    }
    return reminders;
  });
});

final partyRemindersStreamProvider = StreamProvider.family<List<ReminderModel>, String>((ref, partyId) {
  return ref.watch(reminderServiceProvider).getPartyReminders(partyId);
});

class ReminderNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  Future<void> createReminder({
    required String partyId,
    required String partyName,
    required String partyPhone,
    required String title,
    required String note,
    required DateTime date,
  }) async {
    state = const AsyncValue.loading();
    try {

      final reminder = ReminderModel(
        id: '',
        partyId: partyId,
        partyName: partyName,
        partyPhone: partyPhone,
        title: title,
        note: note,
        date: date,
        status: ReminderStatus.upcoming,
        createdAt: TimeUtils.now,
      );

      await ref.read(reminderServiceProvider).createReminder(reminder);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateReminder(ReminderModel reminder) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(reminderServiceProvider).updateReminder(reminder);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> markAsDone(String id) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(reminderServiceProvider).markAsDone(id);
      await NotificationService().cancelReminderNotification(id);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteReminder(String id) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(reminderServiceProvider).deleteReminder(id);
      await NotificationService().cancelReminderNotification(id);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final reminderNotifierProvider = NotifierProvider<ReminderNotifier, AsyncValue<void>>(ReminderNotifier.new);
