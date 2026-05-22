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
    // To test with a local backend on your PC, uncomment the line below:
    // if (kDebugMode) return 'http://192.168.29.24:5000';

    return 'https://appapi.swastikjewel.in';
  }
}
