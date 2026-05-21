import './items_widget.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';

final deviceInfoPlugin = DeviceInfoPlugin();

showAndroidInfo() {
  return FutureBuilder(
      future: deviceInfoPlugin.androidInfo,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              snapshot.error.toString(),
            ),
          );
        } else if (snapshot.hasData) {
          AndroidDeviceInfo info = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                item('Android Model', info.model),
                item('Android Brand', info.brand),
                item('Android Device', info.device),
                item('Android Hardware', info.hardware),
                item('Android Host', info.host),
                item('Android ID', info.id),
                item(
                  'Android SDK int',
                  info.version.sdkInt.toString(),
                ),
              ],
            ),
          );
        } else {
          return const CircularProgressIndicator();
        }
      });
}

