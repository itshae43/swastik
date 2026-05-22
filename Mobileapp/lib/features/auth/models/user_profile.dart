class UserProfileModel {
  final String id;
  final String name;
  final String mobile;
  final String status; // inactive | pending_approval | approved
  final bool sessionActive;
  final bool requestPending;
  final DateTime? requestedAt;
  final DateTime? lastApprovalTime;
  final String? approvedBy;
  final UserProfileDeviceInfo deviceInfo;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserProfileModel({
    required this.id,
    required this.name,
    required this.mobile,
    required this.status,
    required this.sessionActive,
    required this.requestPending,
    this.requestedAt,
    this.lastApprovalTime,
    this.approvedBy,
    required this.deviceInfo,
    this.createdAt,
    this.updatedAt,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      mobile: json['mobile'] ?? '',
      status: json['status'] ?? 'inactive',
      sessionActive: json['sessionActive'] ?? false,
      requestPending: json['requestPending'] ?? false,
      requestedAt: json['requestedAt'] != null
          ? DateTime.tryParse(json['requestedAt'].toString())
          : null,
      lastApprovalTime: json['lastApprovalTime'] != null
          ? DateTime.tryParse(json['lastApprovalTime'].toString())
          : null,
      approvedBy: json['approvedBy'],
      deviceInfo: UserProfileDeviceInfo.fromJson(json['deviceInfo'] ?? {}),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'mobile': mobile,
      'status': status,
      'sessionActive': sessionActive,
      'requestPending': requestPending,
      'requestedAt': requestedAt?.toIso8601String(),
      'lastApprovalTime': lastApprovalTime?.toIso8601String(),
      'approvedBy': approvedBy,
      'deviceInfo': deviceInfo.toJson(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  UserProfileModel copyWith({
    String? id,
    String? name,
    String? mobile,
    String? status,
    bool? sessionActive,
    bool? requestPending,
    DateTime? requestedAt,
    DateTime? lastApprovalTime,
    String? approvedBy,
    UserProfileDeviceInfo? deviceInfo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfileModel(
      id: id ?? this.id,
      name: name ?? this.name,
      mobile: mobile ?? this.mobile,
      status: status ?? this.status,
      sessionActive: sessionActive ?? this.sessionActive,
      requestPending: requestPending ?? this.requestPending,
      requestedAt: requestedAt ?? this.requestedAt,
      lastApprovalTime: lastApprovalTime ?? this.lastApprovalTime,
      approvedBy: approvedBy ?? this.approvedBy,
      deviceInfo: deviceInfo ?? this.deviceInfo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class UserProfileDeviceInfo {
  final String deviceModel;
  final String platform;

  UserProfileDeviceInfo({
    required this.deviceModel,
    required this.platform,
  });

  factory UserProfileDeviceInfo.fromJson(Map<String, dynamic> json) {
    return UserProfileDeviceInfo(
      deviceModel: json['deviceModel'] ?? '',
      platform: json['platform'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deviceModel': deviceModel,
      'platform': platform,
    };
  }
}
