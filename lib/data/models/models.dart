import '../../core/utils/date_helpers.dart';

enum MovementType { income, expense }

extension MovementTypeX on MovementType {
  String get dbValue => this == MovementType.income ? 'income' : 'expense';

  String get labelEs => this == MovementType.income ? 'Ingreso' : 'Gasto';

  static MovementType fromDb(String value) =>
      value == 'income' ? MovementType.income : MovementType.expense;
}

/// A single income or expense entry.
///
/// `categoryName` and `clientName` are join-time display fields: they are
/// populated by read queries, never written to the movements table.
class Movement {
  final int? id;
  final MovementType type;
  final double amount;
  final DateTime date;
  final int? serviceId;
  final int? expenseCategoryId;
  final int? clientId;
  final String? employee;
  final String? supplier;
  final String paymentMethod;
  final String? note;
  final DateTime createdAt;

  // Display-only join fields.
  final String? categoryName;
  final String? clientName;

  const Movement({
    this.id,
    required this.type,
    required this.amount,
    required this.date,
    this.serviceId,
    this.expenseCategoryId,
    this.clientId,
    this.employee,
    this.supplier,
    this.paymentMethod = 'efectivo',
    this.note,
    required this.createdAt,
    this.categoryName,
    this.clientName,
  });

  bool get isIncome => type == MovementType.income;

  Map<String, Object?> toMap() => {
        'id': id,
        'type': type.dbValue,
        'amount': amount,
        'date': DateHelpers.dateTimeKey(date),
        'service_id': serviceId,
        'expense_category_id': expenseCategoryId,
        'client_id': clientId,
        'employee': employee,
        'supplier': supplier,
        'payment_method': paymentMethod,
        'note': note,
        'created_at': DateHelpers.dateTimeKey(createdAt),
      };

  factory Movement.fromMap(Map<String, Object?> map) => Movement(
        id: map['id'] as int?,
        type: MovementTypeX.fromDb(map['type'] as String),
        amount: (map['amount'] as num).toDouble(),
        date: DateTime.parse(map['date'] as String),
        serviceId: map['service_id'] as int?,
        expenseCategoryId: map['expense_category_id'] as int?,
        clientId: map['client_id'] as int?,
        employee: map['employee'] as String?,
        supplier: map['supplier'] as String?,
        paymentMethod: map['payment_method'] as String? ?? 'efectivo',
        note: map['note'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        categoryName: map['category_name'] as String?,
        clientName: map['client_name'] as String?,
      );

  Movement copyWith({
    int? id,
    MovementType? type,
    double? amount,
    DateTime? date,
    int? serviceId,
    int? expenseCategoryId,
    int? clientId,
    String? employee,
    String? supplier,
    String? paymentMethod,
    String? note,
    DateTime? createdAt,
    String? categoryName,
    String? clientName,
  }) =>
      Movement(
        id: id ?? this.id,
        type: type ?? this.type,
        amount: amount ?? this.amount,
        date: date ?? this.date,
        serviceId: serviceId ?? this.serviceId,
        expenseCategoryId: expenseCategoryId ?? this.expenseCategoryId,
        clientId: clientId ?? this.clientId,
        employee: employee ?? this.employee,
        supplier: supplier ?? this.supplier,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        note: note ?? this.note,
        createdAt: createdAt ?? this.createdAt,
        categoryName: categoryName ?? this.categoryName,
        clientName: clientName ?? this.clientName,
      );
}

class Client {
  final int? id;
  final String name;
  final String? phone;
  final String? notes;
  final DateTime createdAt;

  const Client({
    this.id,
    required this.name,
    this.phone,
    this.notes,
    required this.createdAt,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'notes': notes,
        'created_at': DateHelpers.dateTimeKey(createdAt),
      };

  factory Client.fromMap(Map<String, Object?> map) => Client(
        id: map['id'] as int?,
        name: map['name'] as String,
        phone: map['phone'] as String?,
        notes: map['notes'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

class ServiceItem {
  final int? id;
  final String name;
  final double price;
  final bool active;

  const ServiceItem({
    this.id,
    required this.name,
    this.price = 0,
    this.active = true,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'price': price,
        'active': active ? 1 : 0,
      };

  factory ServiceItem.fromMap(Map<String, Object?> map) => ServiceItem(
        id: map['id'] as int?,
        name: map['name'] as String,
        price: (map['price'] as num).toDouble(),
        active: (map['active'] as int) == 1,
      );
}

class ExpenseCategory {
  final int? id;
  final String name;
  final bool active;

  const ExpenseCategory({this.id, required this.name, this.active = true});

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'active': active ? 1 : 0,
      };

  factory ExpenseCategory.fromMap(Map<String, Object?> map) =>
      ExpenseCategory(
        id: map['id'] as int?,
        name: map['name'] as String,
        active: (map['active'] as int) == 1,
      );
}

class CashClose {
  final int? id;
  final DateTime date;
  final double totalIncome;
  final double totalExpense;
  final double net;
  final DateTime closedAt;
  final String? note;

  const CashClose({
    this.id,
    required this.date,
    required this.totalIncome,
    required this.totalExpense,
    required this.net,
    required this.closedAt,
    this.note,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'date': DateHelpers.dayKey(date),
        'total_income': totalIncome,
        'total_expense': totalExpense,
        'net': net,
        'closed_at': DateHelpers.dateTimeKey(closedAt),
        'note': note,
      };

  factory CashClose.fromMap(Map<String, Object?> map) => CashClose(
        id: map['id'] as int?,
        date: DateTime.parse(map['date'] as String),
        totalIncome: (map['total_income'] as num).toDouble(),
        totalExpense: (map['total_expense'] as num).toDouble(),
        net: (map['net'] as num).toDouble(),
        closedAt: DateTime.parse(map['closed_at'] as String),
        note: map['note'] as String?,
      );
}

class MonthlyGoal {
  final String month; // yyyy-MM
  final double amount;

  const MonthlyGoal({required this.month, required this.amount});

  Map<String, Object?> toMap() => {'month': month, 'amount': amount};

  factory MonthlyGoal.fromMap(Map<String, Object?> map) => MonthlyGoal(
        month: map['month'] as String,
        amount: (map['amount'] as num).toDouble(),
      );
}

/// Aggregated totals used across dashboard, reports and cash close.
class Totals {
  final double income;
  final double expense;

  const Totals({required this.income, required this.expense});

  double get net => income - expense;

  static const zero = Totals(income: 0, expense: 0);
}

/// One point of the monthly trend chart.
class MonthPoint {
  final String month; // yyyy-MM
  final double income;
  final double expense;

  const MonthPoint({
    required this.month,
    required this.income,
    required this.expense,
  });
}

/// One slice of the "expenses by category" pie.
class CategorySlice {
  final String name;
  final double total;

  const CategorySlice({required this.name, required this.total});
}
