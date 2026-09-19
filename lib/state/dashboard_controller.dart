import 'package:flutter/foundation.dart';

import '../../core/utils/date_helpers.dart';
import '../../data/models/models.dart';
import '../../data/repositories/finance_repository.dart';
import '../../data/repositories/movement_repository.dart';

enum DashPeriod {
  day('Día'),
  week('Semana'),
  month('Mes'),
  year('Año');

  final String label;
  const DashPeriod(this.label);

  DateTimeRange range([DateTime? now]) {
    final n = now ?? DateTime.now();
    return switch (this) {
      DashPeriod.day => DateTimeRange(start: n, end: n),
      DashPeriod.week => DateHelpers.currentWeek(n),
      DashPeriod.month => DateHelpers.currentMonth(n),
      DashPeriod.year => DateHelpers.currentYear(n),
    };
  }
}

/// Everything the dashboard paints, loaded from the local DB.
class DashboardController extends ChangeNotifier {
  final FinanceRepository _finance;
  final MovementRepository _movements;

  DashboardController({
    FinanceRepository? finance,
    MovementRepository? movements,
  })  : _finance = finance ?? FinanceRepository(),
        _movements = movements ?? MovementRepository();

  DashPeriod period = DashPeriod.month;

  Totals totals = Totals.zero;
  List<CategorySlice> expenseSlices = const [];
  List<MonthPoint> trend = const [];
  List<Movement> lastMovements = const [];

  MonthlyGoal? goal;
  double monthIncome = 0;
  bool todayClosed = false;
  bool loading = true;

  double? get goalProgress {
    final g = goal;
    if (g == null || g.amount <= 0) return null;
    return (monthIncome / g.amount).clamp(0.0, 1.0);
  }

  Future<void> setPeriod(DashPeriod next) async {
    if (period == next) return;
    period = next;
    notifyListeners();
    await refresh();
  }

  Future<void> refresh() async {
    loading = true;
    notifyListeners();
    final now = DateTime.now();
    final range = period.range(now);
    final monthRange = DashPeriod.month.range(now);

    final results = await Future.wait([
      _finance.totalsForRange(range),
      _finance.expensesByCategory(range),
      _finance.monthlyTrend(6),
      _movements.latest(5),
      _finance.goalForMonth(DateHelpers.monthKey(now)),
      _finance.totalsForRange(monthRange),
      _finance.isDayClosed(now),
    ]);

    totals = results[0] as Totals;
    expenseSlices = results[1] as List<CategorySlice>;
    trend = results[2] as List<MonthPoint>;
    lastMovements = results[3] as List<Movement>;
    goal = results[4] as MonthlyGoal?;
    monthIncome = (results[5] as Totals).income;
    todayClosed = results[6] as bool;

    loading = false;
    notifyListeners();
  }

  /// Today's figures, independent of the selected dashboard period —
  /// the cash-close sheet always shows the day being closed.
  Future<Totals> totalsForToday() => _finance.totalsForDay(DateTime.now());

  Future<void> setGoal(double amount) async {
    await _finance.setGoal(
      MonthlyGoal(month: DateHelpers.monthKey(DateTime.now()), amount: amount),
    );
    await refresh();
  }

  Future<CashClose> closeToday({String? note}) async {
    final close = await _finance.closeDay(DateTime.now(), note: note);
    await refresh();
    return close;
  }
}
