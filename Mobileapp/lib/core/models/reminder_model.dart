import '../utils/time_utils.dart';

enum ReminderStatus { upcoming, overdue, completed }

class ReminderModel {
  final String id;
  final String partyId;
  final String partyName;
  final String partyPhone;
  final String title;
  final String note;
  final DateTime date;
  final ReminderStatus status;
  final DateTime createdAt;

  const ReminderModel({
    required this.id,
    required this.partyId,
    required this.partyName,
    required this.partyPhone,
    required this.title,
    required this.note,
    required this.date,
    required this.status,
    required this.createdAt,
  });

  factory ReminderModel.fromMap(String id, Map<String, dynamic> map) {
    return ReminderModel(
      id: id,
      partyId: map['partyId'] as String? ?? '',
      partyName: map['partyName'] as String? ?? '',
      partyPhone: map['partyPhone'] as String? ?? '',
      title: map['title'] as String? ?? '',
      note: map['note'] as String? ?? '',
      date: map['date'] != null ? TimeUtils.to2007(DateTime.parse(map['date']).toLocal()) : TimeUtils.now,
      status: ReminderStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ReminderStatus.upcoming,
      ),
      createdAt: map['createdAt'] != null ? TimeUtils.to2007(DateTime.parse(map['createdAt']).toLocal()) : TimeUtils.now,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'partyId': partyId,
      'partyName': partyName,
      'partyPhone': partyPhone,
      'title': title,
      'note': note,
      'date': date.toUtc().toIso8601String(),
      'status': status.name,
      'createdAt': createdAt.toUtc().toIso8601String(),
    };
  }

  ReminderModel copyWith({
    String? title,
    String? note,
    DateTime? date,
    ReminderStatus? status,
  }) {
    return ReminderModel(
      id: id,
      partyId: partyId,
      partyName: partyName,
      partyPhone: partyPhone,
      title: title ?? this.title,
      note: note ?? this.note,
      date: date ?? this.date,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }
}
