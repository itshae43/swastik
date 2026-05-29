import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swastik_mobile_app/core/models/appointment_model.dart';
import 'package:swastik_mobile_app/core/services/appointment_service.dart';
import 'package:swastik_mobile_app/core/services/notification_service.dart';
import 'package:swastik_mobile_app/core/utils/time_utils.dart';

final appointmentServiceProvider = Provider((ref) => AppointmentService());

final appointmentsStreamProvider = StreamProvider<List<AppointmentModel>>((
  ref,
) {
  return ref.watch(appointmentServiceProvider).getAppointments().asyncMap((
    appointments,
  ) async {
    await NotificationService().repairAppointmentSchedules(appointments);
    return appointments;
  });
});

class AppointmentNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  Future<void> createAppointment({
    required String customerName,
    required String phoneNumber,
    required DateTime date,
    required String notes,
    required bool remindBefore,
  }) async {
    state = const AsyncValue.loading();
    try {
      final appointment = AppointmentModel(
        id: '',
        customerName: customerName,
        phoneNumber: phoneNumber,
        date: date,
        notes: notes,
        remindBefore: remindBefore,
        status: AppointmentStatus.upcoming,
        createdAt: TimeUtils.now,
      );

      await ref.read(appointmentServiceProvider).createAppointment(appointment);
      await NotificationService().repairSchedulesFromServer(force: true);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateAppointment(AppointmentModel appointment) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(appointmentServiceProvider).updateAppointment(appointment);
      await NotificationService().repairSchedulesFromServer(force: true);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> markAsDone(String id) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(appointmentServiceProvider).markAsDone(id);
      await NotificationService().cancelAppointmentNotification(id);
      await NotificationService().repairSchedulesFromServer(force: true);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteAppointment(String id) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(appointmentServiceProvider).deleteAppointment(id);
      await NotificationService().cancelAppointmentNotification(id);
      await NotificationService().repairSchedulesFromServer(force: true);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final appointmentNotifierProvider =
    NotifierProvider<AppointmentNotifier, AsyncValue<void>>(
      AppointmentNotifier.new,
    );
