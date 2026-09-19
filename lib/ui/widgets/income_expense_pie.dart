import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';

/// Main pastel pie: mint = earnings, coral = expenses, net in the center.
class IncomeExpensePie extends StatelessWidget {
  final double income;
  final double expense;
  final double size;

  const IncomeExpensePie({
    super.key,
    required this.income,
    required this.expense,
    this.size = 210,
  });

  @override
  Widget build(BuildContext context) {
    final net = income - expense;
    final hasData = income > 0 || expense > 0;

    return SizedBox(
      height: size,
      width: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: size * 0.32,
              startDegreeOffset: -90,
              sections: hasData
                  ? [
                      PieChartSectionData(
                        value: income,
                        color: AppColors.income,
                        showTitle: false,
                        radius: size * 0.16,
                      ),
                      PieChartSectionData(
                        value: expense,
                        color: AppColors.expense,
                        showTitle: false,
                        radius: size * 0.16,
                      ),
                    ]
                  : [
                      PieChartSectionData(
                        value: 1,
                        color: const Color(0xFFEDEAF3),
                        showTitle: false,
                        radius: size * 0.16,
                      ),
                    ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Balance',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                Formatters.moneyCompact(net),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: net >= 0
                      ? AppColors.incomeDeep
                      : AppColors.expenseDeep,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
