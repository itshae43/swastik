import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swastik_mobile_app/features/auth/providers/auth_providers.dart';

class NavigationNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) {
    if (index == 2) {
      final isStaff = ref.read(isStaffProvider);
      if (isStaff) {
        state = 0;
        return;
      }
    }
    state = index;
  }
}

final navigationProvider = NotifierProvider<NavigationNotifier, int>(NavigationNotifier.new);
