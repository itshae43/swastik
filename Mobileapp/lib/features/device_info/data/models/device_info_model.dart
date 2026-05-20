import '../../domain/entities/device_info.dart';

class DeviceInfoModel extends DeviceInfo {
  const DeviceInfoModel({
    required super.brand,
    required super.model,
    required super.device,
    required super.id,
    required super.androidId,
  });

  factory DeviceInfoModel.fromJson(Map<String, dynamic> json) {
    return DeviceInfoModel(
      brand: json['brand'] as String,
      model: json['model'] as String,
      device: json['device'] as String,
      id: json['id'] as String,
      androidId: json['androidId'] as String? ?? 'N/A',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'brand': brand,
      'model': model,
      'device': device,
      'id': id,
      'androidId': androidId,
    };
  }
}
