import '../entities/device_info.dart';

abstract class DeviceInfoRepository {
  Future<DeviceInfo> getDeviceInfo();
}
