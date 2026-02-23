import 'package:intl/intl.dart';

String normalizeBaseUrl(String value) {
  var url = value.trim();
  if (url.endsWith('/')) {
    url = url.substring(0, url.length - 1);
  }
  if (!url.startsWith('http://') && !url.startsWith('https://')) {
    url = 'http://$url';
  }
  return url;
}

String formatCurrency(num value) {
  final formatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  return formatter.format(value);
}

String formatDateTime(dynamic value) {
  if (value == null) {
    return '-';
  }
  DateTime? parsed;
  if (value is String) {
    parsed = DateTime.tryParse(value);
  } else if (value is DateTime) {
    parsed = value;
  }
  if (parsed == null) {
    return value.toString();
  }
  return DateFormat('dd/MM/yyyy HH:mm').format(parsed.toLocal());
}
