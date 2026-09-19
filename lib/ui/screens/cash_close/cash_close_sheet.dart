import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../state/dashboard_controller.dart';

/// Bottom sheet: shows today's summary and confirms the cash close.
Future<void> showCashCloseSheet(BuildContext context) async {
  final controller = context.read<DashboardController>();
  final totals = await controller.totalsForToday();
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      final noteCtrl = TextEditingController();
      var busy = false;

      return StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Cierre de caja · Hoy',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              _SummaryRow(
                label: 'Ingresos',
                value: totals.income,
                color: AppColors.incomeDeep,
              ),
              _SummaryRow(
                label: 'Gastos',
                value: totals.expense,
                color: AppColors.expenseDeep,
              ),
              const Divider(height: 24),
              _SummaryRow(
                label: 'Balance neto',
                value: totals.net,
                color: totals.net >= 0
                    ? AppColors.incomeDeep
                    : AppColors.expenseDeep,
                emphasized: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Nota del cierre (opcional)',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.lock_outline),
                label: Text(busy ? 'Cerrando…' : 'Confirmar cierre'),
                onPressed: busy
                    ? null
                    : () async {
                        setSheetState(() => busy = true);
                        final note = noteCtrl.text.trim();
                        final close = await controller.closeToday(
                          note: note.isEmpty ? null : note,
                        );
                        if (!sheetContext.mounted) return;
                        Navigator.pop(sheetContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            content: Text(
                              'Caja cerrada: ${Formatters.money(close.net)} netos',
                            ),
                          ),
                        );
                      },
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final bool emphasized;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.color,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: emphasized ? 16 : 14,
              fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          Text(
            Formatters.money(value),
            style: TextStyle(
              fontSize: emphasized ? 18 : 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
