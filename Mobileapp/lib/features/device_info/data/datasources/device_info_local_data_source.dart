import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:android_id/android_id.dart';
import '../models/device_info_model.dart';

abstract class DeviceInfoLocalDataSource {
  Future<DeviceInfoModel> getSystemDeviceInfo();
}

class DeviceInfoLocalDataSourceImpl implements DeviceInfoLocalDataSource {
  final DeviceInfoPlugin deviceInfoPlugin;

  DeviceInfoLocalDataSourceImpl({required this.deviceInfoPlugin});

  @override
  Future<DeviceInfoModel> getSystemDeviceInfo() async {
    try {
      if (kIsWeb) {
        final webBrowserInfo = await deviceInfoPlugin.webBrowserInfo;
        return DeviceInfoModel(
          brand: webBrowserInfo.browserName.name,
          model: webBrowserInfo.userAgent ?? 'Web Browser',
          device: webBrowserInfo.platform ?? 'Web Browser',
          id: webBrowserInfo.vendor ?? 'Web ID',
          androidId: 'N/A',
        );
      }

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        String androidIdValue = 'Unknown Android ID';
        try {
          const androidIdPlugin = AndroidId();
          androidIdValue = await androidIdPlugin.getId() ?? 'Unknown Android ID';
        } catch (e) {
          androidIdValue = 'Unavailable';
        }
        
        return DeviceInfoModel(
          brand: androidInfo.brand,
          model: androidInfo.model,
          device: androidInfo.device,
          id: androidInfo.id,
          androidId: androidIdValue,
        );
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        return DeviceInfoModel(
          brand: 'Apple',
          model: iosInfo.model,
          device: iosInfo.name,
          id: iosInfo.identifierForVendor ?? 'Unknown iOS ID',
          androidId: 'N/A',
        );
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfoPlugin.windowsInfo;
        return DeviceInfoModel(
          brand: 'Windows PC',
          model: windowsInfo.computerName,
          device: 'Windows Machine',
          id: windowsInfo.deviceId,
          androidId: 'N/A',
        );
      } else if (Platform.isMacOS) {
        final macInfo = await deviceInfoPlugin.macOsInfo;
        return DeviceInfoModel(
          brand: 'Apple Mac',
          model: macInfo.model,
          device: macInfo.computerName,
          id: macInfo.systemGUID ?? 'Unknown Mac ID',
          androidId: 'N/A',
        );
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfoPlugin.linuxInfo;
        return DeviceInfoModel(
          brand: linuxInfo.name,
          model: linuxInfo.id,
          device: linuxInfo.variant ?? 'Linux',
          id: linuxInfo.machineId ?? 'Unknown Linux ID',
          androidId: 'N/A',
        );
      }
    } catch (e) {
      // Fallback for any generic platform exceptions or type cast issues
      return DeviceInfoModel(
        brand: 'Generic',
        model: 'Generic Platform',
        device: 'Generic Device',
        id: 'Error: ${e.toString()}',
        androidId: 'N/A',
      );
    }

    return const DeviceInfoModel(
      brand: 'Generic',
      model: 'Generic Platform',
      device: 'Generic Device',
      id: 'Unknown ID',
      androidId: 'N/A',
    );
  }
}
