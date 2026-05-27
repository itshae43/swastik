import '../utils/time_utils.dart';

enum AppointmentStatus { upcoming, completed }

class AppointmentModel {
  final String id;
  final String customerName;
  final String phoneNumber;
  final DateTime date;
  final String notes;
  final bool remindBefore;
  final AppointmentStatus status;
  final DateTime createdAt;

  const AppointmentModel({
    required this.id,
    required this.customerName,
    required this.phoneNumber,
    required this.date,
    required this.notes,
    required this.remindBefore,
    required this.status,
    required this.createdAt,
  });

  factory AppointmentModel.fromMap(String id, Map<String, dynamic> map) {
    return AppointmentModel(
      id: id,
      customerName: map['customerName'] as String? ?? '',
      phoneNumber: map['phoneNumber'] as String? ?? '',
      date: map['date'] != null ? TimeUtils.to2007(DateTime.parse(map['date']).toLocal()) : TimeUtils.now,
      notes: map['notes'] as String? ?? '',
      remindBefore: map['remindBefore'] as bool? ?? false,
      status: AppointmentStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => AppointmentStatus.upcoming,
      ),
      createdAt: map['createdAt'] != null ? TimeUtils.to2007(DateTime.parse(map['createdAt']).toLocal()) : TimeUtils.now,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerName': customerName,
      'phoneNumber': phoneNumber,
      'date': date.toUtc().toIso8601String(),
      'notes': notes,
      'remindBefore': remindBefore,
      'status': status.name,
      'createdAt': createdAt.toUtc().toIso8601String(),
    };
  }

  AppointmentModel copyWith({
    String? customerName,
    String? phoneNumber,
    DateTime? date,
    String? notes,
    bool? remindBefore,
    AppointmentStatus? status,
  }) {
    return AppointmentModel(
      id: id,
      customerName: customerName ?? this.customerName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      remindBefore: remindBefore ?? this.remindBefore,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }
}
