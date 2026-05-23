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
      return 'https://694d-116-74-8-20.ngrok-free.app';
      }
    return 'https://appapi.swastikjewel.in';
  }
}
