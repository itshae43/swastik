import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/reminder_model.dart';

import 'package:swastik_mobile_app/core/utils/constants.dart';

class ReminderService {
  final String baseUrl = AppConstants.baseUrl;

  Stream<List<ReminderModel>> getReminders(String userId) async* {
    while (true) {
      try {
        final res = await http.get(Uri.parse('$baseUrl/reminders'));
        if (res.statusCode == 200) {
          final List data = jsonDecode(res.body);
          yield data.map((e) => ReminderModel.fromMap(e['_id'], e as Map<String, dynamic>)).toList();
        }
      } catch (e) {}
      await Future.delayed(const Duration(seconds: 3));
    }
  }

  Stream<List<ReminderModel>> getPartyReminders(String partyId) async* {
    while (true) {
      try {
        final res = await http.get(Uri.parse('$baseUrl/reminders'));
        if (res.statusCode == 200) {
          final List data = jsonDecode(res.body);
          final all = data.map((e) => ReminderModel.fromMap(e['_id'], e as Map<String, dynamic>)).toList();
          yield all.where((r) => r.partyId == partyId).toList();
        }
      } catch (e) {}
      await Future.delayed(const Duration(seconds: 3));
    }
  }

  Future<void> createReminder(ReminderModel reminder) async {
    await http.post(
      Uri.parse('$baseUrl/reminders'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(reminder.toMap()),
    );
  }

  Future<void> updateReminder(ReminderModel reminder) async {
    await http.put(
      Uri.parse('$baseUrl/reminders/${reminder.id}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(reminder.toMap()),
    );
  }

  Future<void> deleteReminder(String id) async {
    await http.delete(Uri.parse('$baseUrl/reminders/$id'));
  }

  Future<void> markAsDone(String id) async {
    // Note: since we only have full object PUT, we might need to fetch it first.
    // However, since this is a quick fix, let's fetch it, update status, and PUT.
    final res = await http.get(Uri.parse('$baseUrl/reminders'));
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      final rMap = data.firstWhere((r) => r['_id'] == id, orElse: () => null);
      if (rMap != null) {
        final reminder = ReminderModel.fromMap(rMap['_id'], rMap);
        final updated = reminder.copyWith(status: ReminderStatus.completed);
        await updateReminder(updated);
      }
    }
  }
}
