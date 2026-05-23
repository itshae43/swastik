import 'package:timezone/timezone.dart' as tz;

class TimeUtils {
  static tz.TZDateTime get istNow {
    final location = tz.getLocation('Asia/Kolkata');
    return tz.TZDateTime.now(location);
  }
  
  static tz.TZDateTime convertToIst(DateTime dateTime) {
    final location = tz.getLocation('Asia/Kolkata');
    return tz.TZDateTime.from(dateTime, location);
  }
}
