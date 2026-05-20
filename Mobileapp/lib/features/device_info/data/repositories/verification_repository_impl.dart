import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../domain/entities/device_info.dart';
import '../../domain/repositories/verification_repository.dart';

class VerificationRepositoryImpl implements VerificationRepository {
  final http.Client _client;

  VerificationRepositoryImpl({http.Client? client}) : _client = client ?? http.Client();

  @override
  Future<Map<String, dynamic>> verifyDevice(DeviceInfo deviceInfo) async {
    // 10.0.2.2 is the gateway to host machine localhost in Android emulators
    // localhost is used for iOS, web, desktop, and unit testing
    final urls = [
      'http://10.0.2.2:5000/api/verify',
      'http://localhost:5000/api/verify',
    ];

    Map<String, String> body = {
      'brand': deviceInfo.brand,
      'model': deviceInfo.model,
      'androidId': deviceInfo.androidId,
    };

    dynamic lastError;

    for (var url in urls) {
      try {
        debugPrint('Attempting verification call to: $url');
        final response = await _client.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          return jsonDecode(response.body);
        } else {
          lastError = 'Server returned status code: ${response.statusCode}';
        }
      } catch (e) {
        debugPrint('Failed to connect to $url: $e');
        lastError = e;
      }
    }

    throw Exception('Failed to connect to verification server. Error: $lastError');
  }
}
