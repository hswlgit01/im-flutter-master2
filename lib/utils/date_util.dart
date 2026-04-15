import 'package:intl/intl.dart';

class DateUtil {
  static String getFormattedTime(int timestamp) {
    try {
      DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime);
    } catch (e) {
      return timestamp.toString();
    }
  }
}