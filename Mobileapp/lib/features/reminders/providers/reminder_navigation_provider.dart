import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReminderNavigationRequest {
  final int tabIndex;
  final String filter;
  final int sequence;

  const ReminderNavigationRequest({
    required this.tabIndex,
    required this.filter,
    required this.sequence,
  });
}

class ReminderNavigationNotifier extends Notifier<ReminderNavigationRequest?> {
  int _sequence = 0;

  @override
  ReminderNavigationRequest? build() => null;

  void showReminders({String filter = 'All'}) {
    _show(tabIndex: 0, filter: filter);
  }

  void showAppointments({String filter = 'All'}) {
    _show(tabIndex: 1, filter: filter);
  }

  void _show({required int tabIndex, required String filter}) {
    _sequence += 1;
    state = ReminderNavigationRequest(
      tabIndex: tabIndex,
      filter: filter,
      sequence: _sequence,
    );
  }
}

final reminderNavigationProvider =
    NotifierProvider<ReminderNavigationNotifier, ReminderNavigationRequest?>(
      ReminderNavigationNotifier.new,
    );
