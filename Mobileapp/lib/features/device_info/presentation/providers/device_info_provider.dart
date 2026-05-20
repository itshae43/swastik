import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../data/datasources/device_info_local_data_source.dart';
import '../../data/repositories/device_info_repository_impl.dart';
import '../../domain/entities/device_info.dart';
import '../../domain/repositories/device_info_repository.dart';
import '../../domain/usecases/get_device_info_usecase.dart';

// Dependency injection providers
final deviceInfoPluginProvider = Provider<DeviceInfoPlugin>((ref) {
  return DeviceInfoPlugin();
});

final deviceInfoLocalDataSourceProvider = Provider<DeviceInfoLocalDataSource>((ref) {
  final deviceInfoPlugin = ref.watch(deviceInfoPluginProvider);
  return DeviceInfoLocalDataSourceImpl(deviceInfoPlugin: deviceInfoPlugin);
});

final deviceInfoRepositoryProvider = Provider<DeviceInfoRepository>((ref) {
  final localDataSource = ref.watch(deviceInfoLocalDataSourceProvider);
  return DeviceInfoRepositoryImpl(localDataSource: localDataSource);
});

final getDeviceInfoUseCaseProvider = Provider<GetDeviceInfoUseCase>((ref) {
  final repository = ref.watch(deviceInfoRepositoryProvider);
  return GetDeviceInfoUseCase(repository);
});

// State provider to fetch and expose DeviceInfo state
final deviceInfoFutureProvider = FutureProvider<DeviceInfo>((ref) async {
  final getDeviceInfoUseCase = ref.watch(getDeviceInfoUseCaseProvider);
  return await getDeviceInfoUseCase();
});
