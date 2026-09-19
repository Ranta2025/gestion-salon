import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';

/// Secondary pie: how expenses split across categories, with legend.
class ExpenseCategoryPie extends StatelessWidget {
  final List<CategorySlice> slices;
  final double size;

  const ExpenseCategoryPie({super.key, required this.slices, this.size = 170});

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'Sin gastos en este período',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    final total = slices.fold<double>(0, (sum, s) => sum + s.total);

    return Column(
      children: [
        SizedBox(
          height: size,
          width: size,
          child: PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: size * 0.28,
              startDegreeOffset: -90,
              sections: [
                for (var i = 0; i < slices.length; i++)
                  PieChartSectionData(
                    value: slices[i].total,
                    color: AppColors.categoryColor(i),
                    showTitle: false,
                    radius: size * 0.2,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < slices.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.categoryColor(i),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    slices[i].name,
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${Formatters.money(slices[i].total)} '
                  '(${Formatters.percent(slices[i].total / total * 100)})',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
