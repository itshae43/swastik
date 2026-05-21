import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

class CommunicationUtils {
  static Future<void> makeCall(String phoneNumber) async {
    if (phoneNumber.trim().isEmpty) return;
    
    // Remove characters that aren't digits or '+'
    var cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    
    // Auto-prepend country code '+91' (India) if it's a 10-digit number
    if (cleanPhone.length == 10) {
      cleanPhone = '+91$cleanPhone';
    } else if (cleanPhone.length == 12 && cleanPhone.startsWith('91')) {
      cleanPhone = '+$cleanPhone';
    }

    final Uri launchUri = Uri.parse('tel:$cleanPhone');
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        // Fallback: launch directly in case canLaunchUrl returned false due to package visibility
        await launchUrl(launchUri);
      }
    } catch (_) {
      try {
        await launchUrl(launchUri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  static Future<void> sendSMS(String phoneNumber) async {
    if (phoneNumber.trim().isEmpty) return;
    
    // Remove characters that aren't digits or '+'
    var cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    
    // Auto-prepend country code '+91' (India) if it's a 10-digit number
    if (cleanPhone.length == 10) {
      cleanPhone = '+91$cleanPhone';
    } else if (cleanPhone.length == 12 && cleanPhone.startsWith('91')) {
      cleanPhone = '+$cleanPhone';
    }

    final Uri launchUri = Uri.parse('sms:$cleanPhone');
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        await launchUrl(launchUri);
      }
    } catch (_) {
      try {
        await launchUrl(launchUri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  static Future<void> launchWhatsApp(String phoneNumber, String message) async {
    if (phoneNumber.trim().isEmpty) return;
    // Remove non-numeric characters
    var cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');
    
    // Auto-prepend country code '91' (India) if it's a 10-digit number
    if (cleanPhone.length == 10) {
      cleanPhone = '91$cleanPhone';
    }
    
    final Uri whatsappAppUri = Uri.parse("whatsapp://send?phone=$cleanPhone&text=${Uri.encodeComponent(message)}");
    final Uri whatsappWebUri = Uri.parse("https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}");

    // 1. Try launching whatsapp:// scheme strictly in the native app
    try {
      await launchUrl(whatsappAppUri, mode: LaunchMode.externalNonBrowserApplication);
      return;
    } catch (_) {}

    // 2. Try launching https://wa.me/ universal link strictly in the native app
    try {
      await launchUrl(whatsappWebUri, mode: LaunchMode.externalNonBrowserApplication);
      return;
    } catch (_) {}

    // 3. Try launching whatsapp:// scheme with relaxed application mode
    try {
      await launchUrl(whatsappAppUri, mode: LaunchMode.externalApplication);
      return;
    } catch (_) {}

    // 4. Final fallback: open in browser/default app handler
    try {
      await launchUrl(whatsappWebUri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}
