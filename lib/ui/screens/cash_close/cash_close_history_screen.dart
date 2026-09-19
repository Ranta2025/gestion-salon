import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_helpers.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/finance_repository.dart';

/// Read-only history of closed days, newest first.
class CashCloseHistoryScreen extends StatelessWidget {
  const CashCloseHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final finance = context.read<FinanceRepository>();

    return Scaffold(
      appBar: AppBar(title: const Text('Cierres de caja')),
      body: FutureBuilder<List<CashClose>>(
        future: finance.listCloses(),
        builder: (context, snapshot) {
          final closes = snapshot.data;
          if (closes == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (closes.isEmpty) {
            return const Center(
              child: Text(
                'Todavía no hay cierres registrados',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: closes.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final close = closes[index];
              final positive = close.net >= 0;
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.goal.withValues(alpha: 0.4),
                      child: const Icon(Icons.lock_outline, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateHelpers.humanDate(close.date),
                            style:
                                const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'Ingresos ${Formatters.money(close.totalIncome)} · '
                            'Gastos ${Formatters.money(close.totalExpense)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      Formatters.money(close.net),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: positive
                            ? AppColors.incomeDeep
                            : AppColors.expenseDeep,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
