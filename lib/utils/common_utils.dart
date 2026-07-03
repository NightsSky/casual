import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

String formatTime(DateTime? dateTime, {String locale = 'en'}) {
  if (dateTime == null) return '';
  if (locale.startsWith('zh')) {
    timeago.setLocaleMessages('zh_CN', timeago.ZhCnMessages());
    return timeago.format(dateTime, locale: 'zh_CN');
  }
  return timeago.format(dateTime);
}

String formatDate(DateTime? dateTime,
    {String format = 'yyyy-MM-dd HH:mm', String? locale}) {
  if (dateTime == null) return '';
  return DateFormat(format, locale).format(dateTime);
}

String formatFileSize(int bytes) {
  if (bytes == 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB'];
  final i = (bytes == 0) ? 0 : (63 - bytes.bitLength) ~/ 10;
  final size = bytes / (1 << (i * 10));
  return '${size.toStringAsFixed(1)} ${units[i]}';
}

String sanitizeFileName(String name) {
  return name
      .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
      .replaceAll(RegExp(r'\s+'), '-')
      .substring(0, name.length > 100 ? 100 : name.length);
}

bool isEmpty(dynamic value) {
  if (value == null) return true;
  if (value is String) return value.trim().isEmpty;
  if (value is Iterable) return value.isEmpty;
  if (value is Map) return value.isEmpty;
  return false;
}
