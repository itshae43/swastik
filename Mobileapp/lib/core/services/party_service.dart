import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/party_model.dart';

import 'package:swastik_mobile_app/core/utils/constants.dart';

class PartyService {
  final String baseUrl = AppConstants.baseUrl;

  // ─── CREATE PARTY ──────────────────────────────────────────────────
  Future<String> createParty(PartyModel party) async {
    final response = await http.post(
      Uri.parse('$baseUrl/parties'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(party.toMap()),
    );
    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return data['_id'];
    }
    throw Exception('Failed to create party');
  }

  // ─── GET PARTIES STREAM ─────────────────────────────────────────────
  Stream<List<PartyModel>> partiesStream(String userId) async* {
    while (true) {
      try {
        final response = await http.get(Uri.parse('$baseUrl/parties'));
        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          yield data.map((e) => PartyModel.fromMap(e['_id'], e as Map<String, dynamic>)).toList();
        }
      } catch (e) {
        // Silently ignore network errors in polling
      }
      await Future.delayed(const Duration(seconds: 3));
    }
  }

  // ─── UPDATE PARTY ──────────────────────────────────────────────────
  Future<void> updateParty(PartyModel party) async {
    await http.put(
      Uri.parse('$baseUrl/parties/${party.id}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(party.toMap()),
    );
  }

  // ─── DELETE PARTY ──────────────────────────────────────────────────
  Future<void> deleteParty(String userId, String partyId) async {
    await http.delete(Uri.parse('$baseUrl/parties/$partyId'));
  }
}
