import 'dart:io';
import 'package:android_id/android_id.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

class DeviceIdentity {
  static String androidId = 'unknown';
  static String brand = 'unknown';
  static String model = 'unknown';

  static Future<void> init() async {
    try {
      final deviceInfoPlugin = DeviceInfoPlugin();
      const androidIdPlugin = AndroidId();

      if (kIsWeb) {
        androidId = 'web_browser';
        brand = 'web';
        model = 'browser';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        androidId = await androidIdPlugin.getId() ?? 'unknown_android';
        brand = androidInfo.brand;
        model = androidInfo.model;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        androidId = iosInfo.identifierForVendor ?? 'unknown_ios';
        brand = 'Apple';
        model = iosInfo.model;
      } else {
        androidId = 'desktop_platform';
        brand = Platform.operatingSystem;
        model = 'Generic';
      }
      debugPrint('[DeviceIdentity] Initialized: androidId=$androidId, brand=$brand, model=$model');
    } catch (e) {
      debugPrint('[DeviceIdentity] Error initializing device identity: $e');
    }
  }
}
