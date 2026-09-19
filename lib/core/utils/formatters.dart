import 'package:intl/intl.dart';

/// Money and number formatting. The currency symbol is configurable at
/// runtime (Settings) and defaults to '$'.
class Formatters {
  Formatters._();

  static String currencySymbol = '\$';

  static final NumberFormat _twoDecimals = NumberFormat('#,##0.00', 'es');
  static final NumberFormat _compact = NumberFormat.compact(locale: 'es');

  static String money(num value) =>
      '$currencySymbol${_twoDecimals.format(value)}';

  /// Short form for chart centers and tight spaces, e.g. `$12,5 mil`.
  static String moneyCompact(num value) =>
      '$currencySymbol${_compact.format(value)}';

  static String percent(num value) => '${value.toStringAsFixed(0)}%';
}
