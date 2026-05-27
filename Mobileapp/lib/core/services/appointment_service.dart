import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/appointment_model.dart';
import 'package:swastik_mobile_app/core/utils/constants.dart';

class AppointmentService {
  final String baseUrl = AppConstants.baseUrl;

  Stream<List<AppointmentModel>> getAppointments() async* {
    while (true) {
      try {
        final res = await http.get(Uri.parse('$baseUrl/appointments'));
        if (res.statusCode == 200) {
          final List data = jsonDecode(res.body);
          yield data.map((e) => AppointmentModel.fromMap(e['_id'], e as Map<String, dynamic>)).toList();
        }
      } catch (e) {}
      await Future.delayed(const Duration(seconds: 3));
    }
  }

  Future<void> createAppointment(AppointmentModel appointment) async {
    await http.post(
      Uri.parse('$baseUrl/appointments'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(appointment.toMap()),
    );
  }

  Future<void> updateAppointment(AppointmentModel appointment) async {
    await http.put(
      Uri.parse('$baseUrl/appointments/${appointment.id}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(appointment.toMap()),
    );
  }

  Future<void> deleteAppointment(String id) async {
    await http.delete(Uri.parse('$baseUrl/appointments/$id'));
  }

  Future<void> markAsDone(String id) async {
    final res = await http.get(Uri.parse('$baseUrl/appointments'));
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      final rMap = data.firstWhere((r) => r['_id'] == id, orElse: () => null);
      if (rMap != null) {
        final appointment = AppointmentModel.fromMap(rMap['_id'], rMap);
        final updated = appointment.copyWith(status: AppointmentStatus.completed);
        await updateAppointment(updated);
      }
    }
  }
}
