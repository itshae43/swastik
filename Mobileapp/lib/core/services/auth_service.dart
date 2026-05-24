import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:android_id/android_id.dart';

import 'package:swastik_mobile_app/core/utils/constants.dart';

class AuthService {
  final String baseUrl = AppConstants.baseUrl;

  Future<bool> verifyDevice() async {
    try {
      debugPrint('═══════════════════════════════════════════');
      debugPrint('[AuthService] Starting device verification');
      debugPrint('[AuthService] Base URL: $baseUrl');

      final deviceInfoPlugin = DeviceInfoPlugin();
      final androidInfo = await deviceInfoPlugin.androidInfo;

      const androidIdPlugin = AndroidId();
      final String? androidId = await androidIdPlugin.getId();

      debugPrint('[AuthService] Android ID: $androidId');
      debugPrint('[AuthService] Brand: ${androidInfo.brand}');
      debugPrint('[AuthService] Model: ${androidInfo.model}');

      if (androidId == null) {
        debugPrint('[AuthService] ERROR: androidId is null — cannot verify');
        return false;
      }

      final url = '$baseUrl/verify';
      final body = jsonEncode({
        'androidId': androidId,
        'brand': androidInfo.brand,
        'model': androidInfo.model,
      });

      debugPrint('[AuthService] POST $url');
      debugPrint('[AuthService] Body: $body');

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 15));

      debugPrint('[AuthService] Status: ${response.statusCode}');
      debugPrint('[AuthService] Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final verified = data['verified'] == true;
        debugPrint('[AuthService] Verified: $verified');
        return verified;
      }

      debugPrint('[AuthService] Non-200 status code — returning false');
      return false;
    } on SocketException catch (e) {
      debugPrint('[AuthService] SocketException (no internet / server unreachable): $e');
      rethrow;
    } on http.ClientException catch (e) {
      debugPrint('[AuthService] ClientException (connection refused / SSL issue): $e');
      rethrow;
    } on FormatException catch (e) {
      debugPrint('[AuthService] FormatException (bad JSON response): $e');
      rethrow;
    } catch (e, stack) {
      debugPrint('[AuthService] UNEXPECTED ERROR: $e');
      debugPrint('[AuthService] Stack trace:\n$stack');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getDevices() async {
    try {
      final url = '$baseUrl/devices';
      debugPrint('[AuthService] GET $url');
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      debugPrint('[AuthService] Status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => Map<String, dynamic>.from(item)).toList();
      }
      throw Exception('Failed to load devices (status: ${response.statusCode})');
    } catch (e) {
      debugPrint('[AuthService] Error in getDevices: $e');
      rethrow;
    }
  }

  Future<bool> deauthorizeDevice(String id) async {
    try {
      final url = '$baseUrl/devices/$id';
      debugPrint('[AuthService] DELETE $url');
      final response = await http.delete(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      debugPrint('[AuthService] Status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[AuthService] Error in deauthorizeDevice: $e');
      return false;
    }
  }

  Future<DateTime?> getServerTime() async {
    try {
      final url = '$baseUrl/time';
      debugPrint('[AuthService] GET $url');
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      debugPrint('[AuthService] Server time status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return DateTime.parse(data['serverTime']);
      }
    } catch (e) {
      debugPrint('[AuthService] Error in getServerTime: $e');
    }
    return null;
  }
}


