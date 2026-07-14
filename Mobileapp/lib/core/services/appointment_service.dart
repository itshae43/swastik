import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/appointment_model.dart';
import 'package:swastik_mobile_app/core/utils/constants.dart';

class AppointmentService {
  final String baseUrl = AppConstants.baseUrl;

  Future<List<AppointmentModel>> fetchAppointments() async {
    final res = await http.get(Uri.parse('$baseUrl/appointments'));
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data
          .map(
            (e) =>
                AppointmentModel.fromMap(e['_id'], e as Map<String, dynamic>),
          )
          .toList();
    }
    throw Exception('Failed to load appointments (${res.statusCode})');
  }

  Stream<List<AppointmentModel>> getAppointments() async* {
    while (true) {
      try {
        yield await fetchAppointments();
      } catch (_) {
        // Keep the polling stream alive; the next cycle will retry.
      }
      await Future.delayed(const Duration(seconds: 12));
    }
  }

  Future<AppointmentModel> createAppointment(
    AppointmentModel appointment,
  ) async {
    final res = await http.post(
      Uri.parse('$baseUrl/appointments'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(appointment.toMap()),
    );
    if (res.statusCode == 200 || res.statusCode == 201) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return AppointmentModel.fromMap(data['_id'], data);
    }
    throw Exception('Failed to create appointment (${res.statusCode})');
  }

  Future<AppointmentModel> updateAppointment(
    AppointmentModel appointment,
  ) async {
    final res = await http.put(
      Uri.parse('$baseUrl/appointments/${appointment.id}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(appointment.toMap()),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return AppointmentModel.fromMap(data['_id'], data);
    }
    throw Exception('Failed to update appointment (${res.statusCode})');
  }

  Future<void> deleteAppointment(String id) async {
    final res = await http.delete(Uri.parse('$baseUrl/appointments/$id'));
    if (res.statusCode != 200) {
      throw Exception('Failed to delete appointment (${res.statusCode})');
    }
  }

  Future<void> markAsDone(String id) async {
    final appointments = await fetchAppointments();
    final appointment = appointments.cast<AppointmentModel?>().firstWhere(
      (r) => r?.id == id,
      orElse: () => null,
    );
    if (appointment != null) {
      final updated = appointment.copyWith(status: AppointmentStatus.completed);
      await updateAppointment(updated);
    }
  }
}
