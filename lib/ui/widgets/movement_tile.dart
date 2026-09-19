import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/date_helpers.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/labels.dart';
import '../../data/models/models.dart';

/// One movement row: colored icon, category + context, signed amount.
class MovementTile extends StatelessWidget {
  final Movement movement;
  final VoidCallback? onTap;

  const MovementTile({super.key, required this.movement, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isIncome = movement.isIncome;
    final color = isIncome ? AppColors.incomeDeep : AppColors.expenseDeep;
    final bg = isIncome ? AppColors.income : AppColors.expense;

    final subtitleParts = <String>[
      DateHelpers.humanShort(movement.date),
      Labels.payment(movement.paymentMethod),
      if (movement.clientName != null) movement.clientName!,
      if (movement.employee != null && movement.employee!.isNotEmpty)
        movement.employee!,
      if (movement.supplier != null && movement.supplier!.isNotEmpty)
        movement.supplier!,
    ];

    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: bg.withValues(alpha: 0.35),
        child: Icon(
          isIncome ? Icons.arrow_upward : Icons.arrow_downward,
          color: color,
          size: 18,
        ),
      ),
      title: Text(
        movement.categoryName ??
            (isIncome ? 'Ingreso' : 'Gasto'),
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        subtitleParts.join(' · '),
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        '${isIncome ? '+' : '−'}${Formatters.money(movement.amount)}',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
    );
  }
}
