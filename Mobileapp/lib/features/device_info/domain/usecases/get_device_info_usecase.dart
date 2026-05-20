import '../entities/device_info.dart';
import '../repositories/device_info_repository.dart';

class GetDeviceInfoUseCase {
  final DeviceInfoRepository repository;

  GetDeviceInfoUseCase(this.repository);

  Future<DeviceInfo> call() async {
    return await repository.getDeviceInfo();
  }
}
