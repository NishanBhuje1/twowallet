import 'package:intl/intl.dart';

extension CurrencyExt on num {
  String toAUD({bool showCents = true}) {
    final format = NumberFormat.currency(
      locale: 'en_AU',
      symbol: '\$',
      decimalDigits: showCents ? 2 : 0,
    );
    return format.format(this);
  }
}

extension CurrencyStringExt on String {
  String toAUD({bool showCents = true}) {
    final parsed = double.tryParse(this) ?? 0.0;
    final format = NumberFormat.currency(
      locale: 'en_AU',
      symbol: '\$',
      decimalDigits: showCents ? 2 : 0,
    );
    return format.format(parsed);
  }
}