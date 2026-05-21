import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:android_id/android_id.dart';

import 'package:swastik_mobile_app/core/utils/constants.dart';

class AuthService {
  final String baseUrl = AppConstants.baseUrl;

  Future<bool> verifyDevice() async {
    try {
      final deviceInfoPlugin = DeviceInfoPlugin();
      final androidInfo = await deviceInfoPlugin.androidInfo;
      
      const androidIdPlugin = AndroidId();
      final String? androidId = await androidIdPlugin.getId();

      if (androidId == null) return false;

      final response = await http.post(
        Uri.parse('$baseUrl/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'androidId': androidId,
          'brand': androidInfo.brand,
          'model': androidInfo.model,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['verified'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
