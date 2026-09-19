import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/date_helpers.dart';
import '../../data/models/models.dart';

/// Monthly income vs. expense trend (two soft pastel lines).
class TrendChart extends StatelessWidget {
  final List<MonthPoint> points;
  final double height;

  const TrendChart({super.key, required this.points, this.height = 180});

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'Registrá movimientos para ver la tendencia',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    final maxY = points
            .fold<double>(0, (m, p) => [m, p.income, p.expense].reduce(
                  (a, b) => a > b ? a : b,
                )) *
        1.2;

    LineChartBarData line(List<double> values, Color color) =>
        LineChartBarData(
          isCurved: true,
          curveSmoothness: 0.35,
          color: color,
          barWidth: 3,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: color.withValues(alpha: 0.12),
          ),
          spots: [
            for (var i = 0; i < values.length; i++)
              FlSpot(i.toDouble(), values[i]),
          ],
        );

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY == 0 ? 10 : maxY,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: 26,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= points.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      DateHelpers.monthLabel(points[i].month)
                          .split(' ')
                          .first,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            line(points.map((p) => p.income).toList(), AppColors.incomeDeep),
            line(points.map((p) => p.expense).toList(), AppColors.expenseDeep),
          ],
        ),
      ),
    );
  }
}
