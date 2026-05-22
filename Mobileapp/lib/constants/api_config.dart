import 'dart:io';
import 'package:flutter/foundation.dart';

/// Centralized API configuration for the Swastik Mobile App.
///
/// All network calls should reference [ApiConfig.baseUrl] instead of
/// hardcoding URLs, so switching environments only requires a single edit.
class ApiConfig {
  ApiConfig._(); // prevent instantiation

  /// Base URL dynamically switching between local backend (in debug) and production.
  static String get baseUrl {
    if (kDebugMode) {
      if (kIsWeb) {
        return 'http://localhost:5000';
      }
      return Platform.isAndroid ? 'http://10.0.2.2:5000' : 'http://localhost:5000';
    }
    return 'https://appapi.swastikjewel.in';
  }
}
