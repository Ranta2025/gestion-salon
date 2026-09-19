import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';

/// Monthly goal progress bar (goal = month income target).
class GoalProgress extends StatelessWidget {
  final double current;
  final double? goal;
  final VoidCallback? onSetGoal;

  const GoalProgress({
    super.key,
    required this.current,
    required this.goal,
    this.onSetGoal,
  });

  @override
  Widget build(BuildContext context) {
    if (goal == null || goal! <= 0) {
      return InkWell(
        onTap: onSetGoal,
        borderRadius: BorderRadius.circular(12),
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(Icons.flag_outlined, color: AppColors.accentDeep),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Definí una meta mensual de ingresos para ver tu progreso',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      );
    }

    final progress = (current / goal!).clamp(0.0, 1.0);
    final reached = current >= goal!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              reached ? '¡Meta alcanzada! 🎉' : 'Meta del mes',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              '${Formatters.money(current)} / ${Formatters.money(goal!)}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: const Color(0xFFF0EDF7),
            valueColor: const AlwaysStoppedAnimation(AppColors.goal),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          Formatters.percent(progress * 100),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
