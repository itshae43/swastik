import '../../domain/entities/device_info.dart';

abstract class VerificationRepository {
  Future<Map<String, dynamic>> verifyDevice(DeviceInfo deviceInfo);
}
