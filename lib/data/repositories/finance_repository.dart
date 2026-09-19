import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import '../../core/utils/date_helpers.dart';
import '../db/app_database.dart';
import '../models/models.dart';

/// Aggregations for dashboard, reports, goals and cash close.
/// All math happens in SQL; Dart only maps rows.
class FinanceRepository {
  String _dayStart(DateTime d) => '${DateHelpers.dayKey(d)} 00:00:00';
  String _dayEnd(DateTime d) => '${DateHelpers.dayKey(d)} 23:59:59';

  Future<Totals> totalsForRange(DateTimeRange range) async {
    final db = await AppDatabase.database;
    final rows = await db.rawQuery(
      "SELECT "
      "COALESCE(SUM(CASE WHEN type = 'income' THEN amount END), 0) AS income, "
      "COALESCE(SUM(CASE WHEN type = 'expense' THEN amount END), 0) AS expense "
      "FROM movements WHERE date >= ? AND date <= ?",
      [_dayStart(range.start), _dayEnd(range.end)],
    );
    final row = rows.first;
    return Totals(
      income: (row['income'] as num).toDouble(),
      expense: (row['expense'] as num).toDouble(),
    );
  }

  Future<Totals> totalsForDay(DateTime day) =>
      totalsForRange(DateTimeRange(start: day, end: day));

  /// Expenses grouped by category for the secondary pie chart.
  Future<List<CategorySlice>> expensesByCategory(
    DateTimeRange range,
  ) async {
    final db = await AppDatabase.database;
    final rows = await db.rawQuery(
      "SELECT COALESCE(ec.name, 'Sin categoría') AS name, "
      "SUM(m.amount) AS total "
      "FROM movements m "
      "LEFT JOIN expense_categories ec ON m.expense_category_id = ec.id "
      "WHERE m.type = 'expense' AND m.date >= ? AND m.date <= ? "
      "GROUP BY name ORDER BY total DESC",
      [_dayStart(range.start), _dayEnd(range.end)],
    );
    return rows
        .map(
          (r) => CategorySlice(
            name: r['name'] as String,
            total: (r['total'] as num).toDouble(),
          ),
        )
        .toList();
  }

  /// Income/expense per month for the trend chart, oldest first.
  Future<List<MonthPoint>> monthlyTrend(int monthsBack) async {
    final db = await AppDatabase.database;
    final rows = await db.rawQuery(
      "SELECT substr(date, 1, 7) AS month, "
      "COALESCE(SUM(CASE WHEN type = 'income' THEN amount END), 0) AS income, "
      "COALESCE(SUM(CASE WHEN type = 'expense' THEN amount END), 0) AS expense "
      "FROM movements GROUP BY month ORDER BY month DESC LIMIT ?",
      [monthsBack],
    );
    return rows.reversed
        .map(
          (r) => MonthPoint(
            month: r['month'] as String,
            income: (r['income'] as num).toDouble(),
            expense: (r['expense'] as num).toDouble(),
          ),
        )
        .toList();
  }

  // ---- Goals ----

  Future<MonthlyGoal?> goalForMonth(String monthKey) async {
    final db = await AppDatabase.database;
    final rows =
        await db.query('goals', where: 'month = ?', whereArgs: [monthKey]);
    if (rows.isEmpty) return null;
    return MonthlyGoal.fromMap(rows.first);
  }

  Future<void> setGoal(MonthlyGoal goal) async {
    final db = await AppDatabase.database;
    await db.insert(
      'goals',
      goal.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ---- Cash close ----

  /// Upserts the close snapshot for a day (spec: re-closing updates).
  Future<CashClose> closeDay(DateTime day, {String? note}) async {
    final db = await AppDatabase.database;
    final totals = await totalsForDay(day);
    final close = CashClose(
      date: day,
      totalIncome: totals.income,
      totalExpense: totals.expense,
      net: totals.net,
      closedAt: DateTime.now(),
      note: note,
    );
    await db.insert(
      'cash_closes',
      close.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return close;
  }

  Future<bool> isDayClosed(DateTime day) async {
    final db = await AppDatabase.database;
    final rows = await db.query(
      'cash_closes',
      where: 'date = ?',
      whereArgs: [DateHelpers.dayKey(day)],
    );
    return rows.isNotEmpty;
  }

  Future<List<CashClose>> listCloses({int limit = 60}) async {
    final db = await AppDatabase.database;
    final rows =
        await db.query('cash_closes', orderBy: 'date DESC', limit: limit);
    return rows.map(CashClose.fromMap).toList();
  }
}
