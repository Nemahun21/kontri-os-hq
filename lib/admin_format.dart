import 'package:intl/intl.dart';

String relTime(DateTime? date) {
  if (date == null) {
    return 'now';
  }

  final diff = DateTime.now().difference(date);

  if (diff.inSeconds < 60) {
    return 'now';
  }
  if (diff.inMinutes < 60) {
    return '${diff.inMinutes}m';
  }
  if (diff.inHours < 24) {
    return '${diff.inHours}h';
  }
  if (diff.inDays < 30) {
    return '${diff.inDays}d';
  }
  return DateFormat('MMM d').format(date);
}

String shortId(String value) {
  if (value.isEmpty) {
    return '—';
  }
  return value.length <= 8 ? value : value.substring(0, 8);
}

String fmtDate(DateTime date) => DateFormat('MMM d, yyyy').format(date);
