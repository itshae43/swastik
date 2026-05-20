import '../../domain/entities/device_info.dart';
import '../../domain/repositories/device_info_repository.dart';
import '../datasources/device_info_local_data_source.dart';

class DeviceInfoRepositoryImpl implements DeviceInfoRepository {
  final DeviceInfoLocalDataSource localDataSource;

  DeviceInfoRepositoryImpl({required this.localDataSource});

  @override
  Future<DeviceInfo> getDeviceInfo() async {
    return await localDataSource.getSystemDeviceInfo();
  }
}
