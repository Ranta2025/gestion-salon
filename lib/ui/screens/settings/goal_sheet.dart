import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/date_helpers.dart';
import '../../../state/dashboard_controller.dart';

/// Bottom sheet to set the current month's income goal.
Future<void> showGoalSheet(BuildContext context) async {
  final controller = context.read<DashboardController>();
  final amountCtrl = TextEditingController(
    text: controller.goal != null && controller.goal!.amount > 0
        ? controller.goal!.amount.toStringAsFixed(0)
        : '',
  );

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(sheetContext).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Meta de ingresos · '
            '${DateHelpers.monthLabel(DateHelpers.monthKey(DateTime.now()))}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: amountCtrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              hintText: 'Monto objetivo del mes',
              prefixIcon: Icon(Icons.flag_outlined),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              final amount = double.tryParse(
                amountCtrl.text.trim().replaceAll(',', '.'),
              );
              if (amount == null || amount <= 0) return;
              await controller.setGoal(amount);
              if (sheetContext.mounted) Navigator.pop(sheetContext);
            },
            child: const Text('Guardar meta'),
          ),
        ],
      ),
    ),
  );
}
