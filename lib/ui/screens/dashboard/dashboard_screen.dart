import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../state/dashboard_controller.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/expense_category_pie.dart';
import '../../widgets/goal_progress.dart';
import '../../widgets/income_expense_pie.dart';
import '../../widgets/ios_card.dart';
import '../../widgets/movement_tile.dart';
import '../../widgets/section_title.dart';
import '../../widgets/trend_chart.dart';
import '../cash_close/cash_close_sheet.dart';
import '../cash_close/cash_close_history_screen.dart';
import '../movements/movement_form_screen.dart';
import '../settings/goal_sheet.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DashboardController>();

    return RefreshIndicator(
      onRefresh: controller.refresh,
      color: AppColors.accentDeep,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          _PeriodSelector(controller: controller),
          const SizedBox(height: 16),
          IosCard(
            child: Column(
              children: [
                IncomeExpensePie(
                  income: controller.totals.income,
                  expense: controller.totals.expense,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _TotalChip(
                      label: 'Ingresos',
                      value: controller.totals.income,
                      color: AppColors.income,
                      textColor: AppColors.incomeDeep,
                    ),
                    _TotalChip(
                      label: 'Gastos',
                      value: controller.totals.expense,
                      color: AppColors.expense,
                      textColor: AppColors.expenseDeep,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          IosCard(
            child: GoalProgress(
              current: controller.monthIncome,
              goal: controller.goal?.amount,
              onSetGoal: () => showGoalSheet(context),
            ),
          ),
          const SizedBox(height: 16),
          IosCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Tendencia mensual'),
                const SizedBox(height: 12),
                TrendChart(points: controller.trend),
                const SizedBox(height: 8),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _LegendDot(color: AppColors.incomeDeep, label: 'Ingresos'),
                    SizedBox(width: 16),
                    _LegendDot(color: AppColors.expenseDeep, label: 'Gastos'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          IosCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Gastos por categoría'),
                const SizedBox(height: 12),
                ExpenseCategoryPie(slices: controller.expenseSlices),
              ],
            ),
          ),
          const SizedBox(height: 16),
          IosCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Últimos movimientos'),
                if (controller.lastMovements.isEmpty)
                  const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    message:
                        'Todavía no hay movimientos.\nTocá "+" para registrar el primero.',
                  )
                else
                  for (final movement in controller.lastMovements)
                    MovementTile(
                      movement: movement,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              MovementFormScreen(editing: movement),
                          fullscreenDialog: true,
                        ),
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          IosCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppColors.goal.withValues(alpha: 0.4),
                    child: Icon(
                      controller.todayClosed
                          ? Icons.lock
                          : Icons.lock_open_outlined,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  title: Text(
                    controller.todayClosed
                        ? 'Caja de hoy cerrada'
                        : 'Cierre de caja',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    controller.todayClosed
                        ? 'Podés volver a cerrarla para actualizarla'
                        : 'Resumí y cerrá el día de hoy',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  trailing: TextButton(
                    onPressed: () => showCashCloseSheet(context),
                    child: const Text('Cerrar'),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const CashCloseHistoryScreen(),
                      ),
                    ),
                    child: const Text('Ver historial'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  final DashboardController controller;

  const _PeriodSelector({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final period in DashPeriod.values)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: ChoiceChip(
                label: Center(child: Text(period.label)),
                selected: controller.period == period,
                onSelected: (_) => controller.setPeriod(period),
                showCheckmark: false,
              ),
            ),
          ),
      ],
    );
  }
}

class _TotalChip extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final Color textColor;

  const _TotalChip({
    required this.label,
    required this.value,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          Text(
            Formatters.money(value),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
