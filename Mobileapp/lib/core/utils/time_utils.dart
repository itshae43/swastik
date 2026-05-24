import 'package:timezone/timezone.dart' as tz;

class TimeUtils {
  static Duration serverOffset = Duration.zero;

  static tz.TZDateTime get istNow {
    final location = tz.getLocation('Asia/Kolkata');
    final realNow = tz.TZDateTime.now(location).add(serverOffset);
    return to2007(realNow) as tz.TZDateTime;
  }
  
  static tz.TZDateTime convertToIst(DateTime dateTime) {
    final location = tz.getLocation('Asia/Kolkata');
    return tz.TZDateTime.from(dateTime, location);
  }

  static DateTime get now {
    return to2007(DateTime.now().add(serverOffset));
  }

  static DateTime to2007(DateTime dt) {
    int year = 2007;
    int month = dt.month;
    int day = dt.day;
    if (month == 2 && day == 29) {
      day = 28;
    }
    if (dt is tz.TZDateTime) {
      return tz.TZDateTime(
        dt.location,
        year,
        month,
        day,
        dt.hour,
        dt.minute,
        dt.second,
        dt.millisecond,
        dt.microsecond,
      );
    }
    if (dt.isUtc) {
      return DateTime.utc(
        year,
        month,
        day,
        dt.hour,
        dt.minute,
        dt.second,
        dt.millisecond,
        dt.microsecond,
      );
    }
    return DateTime(
      year,
      month,
      day,
      dt.hour,
      dt.minute,
      dt.second,
      dt.millisecond,
      dt.microsecond,
    );
  }

  static DateTime toRealWorld(DateTime dt) {
    final realNow = DateTime.now();
    int year = realNow.year + (dt.year - 2007);
    int month = dt.month;
    int day = dt.day;
    if (month == 2 && day == 29) {
      final isLeap = (year % 4 == 0) && (year % 100 != 0 || year % 400 == 0);
      if (!isLeap) {
        day = 28;
      }
    }
    if (dt is tz.TZDateTime) {
      return tz.TZDateTime(
        dt.location,
        year,
        month,
        day,
        dt.hour,
        dt.minute,
        dt.second,
        dt.millisecond,
        dt.microsecond,
      );
    }
    if (dt.isUtc) {
      return DateTime.utc(
        year,
        month,
        day,
        dt.hour,
        dt.minute,
        dt.second,
        dt.millisecond,
        dt.microsecond,
      );
    }
    return DateTime(
      year,
      month,
      day,
      dt.hour,
      dt.minute,
      dt.second,
      dt.millisecond,
      dt.microsecond,
    );
  }
}
