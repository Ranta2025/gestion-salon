/// Shared Spanish labels for enum-like string values stored in the DB.
class Labels {
  Labels._();

  static const List<String> paymentMethods = [
    'efectivo',
    'transferencia',
    'tarjeta',
    'otro',
  ];

  static const Map<String, String> paymentMethod = {
    'efectivo': 'Efectivo',
    'transferencia': 'Transferencia',
    'tarjeta': 'Tarjeta',
    'otro': 'Otro',
  };

  static String payment(String key) => paymentMethod[key] ?? key;
}
