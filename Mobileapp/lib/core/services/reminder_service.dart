import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/reminder_model.dart';

import 'package:swastik_mobile_app/core/utils/constants.dart';

class ReminderService {
  final String baseUrl = AppConstants.baseUrl;

  Future<List<ReminderModel>> fetchReminders({String? partyId}) async {
    final uri = Uri.parse('$baseUrl/reminders').replace(
      queryParameters: (partyId != null && partyId.isNotEmpty)
          ? {'partyId': partyId}
          : null,
    );
    final res = await http.get(uri);
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data
          .map(
            (e) => ReminderModel.fromMap(e['_id'], e as Map<String, dynamic>),
          )
          .toList();
    }
    throw Exception('Failed to load reminders (${res.statusCode})');
  }

  Stream<List<ReminderModel>> getReminders(String userId) async* {
    while (true) {
      try {
        yield await fetchReminders();
      } catch (_) {
        // Keep the polling stream alive; the next cycle will retry.
      }
      await Future.delayed(const Duration(seconds: 12));
    }
  }

  Stream<List<ReminderModel>> getPartyReminders(String partyId) async* {
    while (true) {
      try {
        // Filter by partyId on the server instead of fetching all reminders.
        yield await fetchReminders(partyId: partyId);
      } catch (_) {
        // Keep the polling stream alive; the next cycle will retry.
      }
      await Future.delayed(const Duration(seconds: 12));
    }
  }

  Future<ReminderModel> createReminder(ReminderModel reminder) async {
    final res = await http.post(
      Uri.parse('$baseUrl/reminders'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(reminder.toMap()),
    );
    if (res.statusCode == 200 || res.statusCode == 201) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return ReminderModel.fromMap(data['_id'], data);
    }
    throw Exception('Failed to create reminder (${res.statusCode})');
  }

  Future<ReminderModel> updateReminder(ReminderModel reminder) async {
    final res = await http.put(
      Uri.parse('$baseUrl/reminders/${reminder.id}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(reminder.toMap()),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return ReminderModel.fromMap(data['_id'], data);
    }
    throw Exception('Failed to update reminder (${res.statusCode})');
  }

  Future<void> deleteReminder(String id) async {
    final res = await http.delete(Uri.parse('$baseUrl/reminders/$id'));
    if (res.statusCode != 200) {
      throw Exception('Failed to delete reminder (${res.statusCode})');
    }
  }

  Future<void> markAsDone(String id) async {
    final reminders = await fetchReminders();
    final reminder = reminders.cast<ReminderModel?>().firstWhere(
      (r) => r?.id == id,
      orElse: () => null,
    );
    if (reminder != null) {
      final updated = reminder.copyWith(status: ReminderStatus.completed);
      await updateReminder(updated);
    }
  }
}
