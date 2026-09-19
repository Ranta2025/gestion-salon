import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_helpers.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/movement_repository.dart';
import '../../../state/catalog_controller.dart';
import '../../../state/movements_controller.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/ios_card.dart';
import '../../widgets/movement_tile.dart';
import 'movement_form_screen.dart';

/// Full movements list with type/date/category/employee filters.
class MovementsScreen extends StatefulWidget {
  const MovementsScreen({super.key});

  @override
  State<MovementsScreen> createState() => _MovementsScreenState();
}

class _MovementsScreenState extends State<MovementsScreen> {
  MovementType? _type;
  DateTimeRange? _range;
  int? _serviceId;
  int? _expenseCategoryId;
  String? _employee;

  @override
  void initState() {
    super.initState();
    _applyFilters();
  }

  void _applyFilters() {
    context.read<MovementsController>().setFilter(
          MovementFilter(
            range: _range,
            type: _type,
            serviceId: _serviceId,
            expenseCategoryId: _expenseCategoryId,
            employee: _employee,
          ),
        );
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange:
          _range ?? DateTimeRange(start: now, end: now),
      locale: const Locale('es'),
    );
    if (picked != null) {
      setState(() => _range = picked);
      _applyFilters();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MovementsController>();
    final catalogs = context.watch<CatalogController>();

    final income = controller.movements
        .where((m) => m.isIncome)
        .fold<double>(0, (sum, m) => sum + m.amount);
    final expense = controller.movements
        .where((m) => !m.isIncome)
        .fold<double>(0, (sum, m) => sum + m.amount);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final option in [null, ...MovementType.values])
                ChoiceChip(
                  label: Text(
                    option == null ? 'Todos' : option.labelEs,
                  ),
                  selected: _type == option,
                  showCheckmark: false,
                  onSelected: (_) => setState(() {
                    _type = option;
                    _serviceId = null;
                    _expenseCategoryId = null;
                    _applyFilters();
                  }),
                ),
              ActionChip(
                avatar: const Icon(Icons.date_range, size: 16),
                label: Text(
                  _range == null
                      ? 'Fechas'
                      : DateHelpers.rangeLabel(_range!),
                ),
                onPressed: _pickRange,
              ),
              if (_range != null)
                ActionChip(
                  avatar: const Icon(Icons.close, size: 16),
                  label: const Text('Limpiar'),
                  onPressed: () => setState(() {
                    _range = null;
                    _applyFilters();
                  }),
                ),
              if (_type == MovementType.income)
                _dropdown<int>(
                  hint: 'Servicio',
                  value: _serviceId,
                  items: [
                    for (final s in catalogs.services)
                      DropdownMenuItem(value: s.id, child: Text(s.name)),
                  ],
                  onChanged: (v) => setState(() {
                    _serviceId = v;
                    _applyFilters();
                  }),
                ),
              if (_type == MovementType.expense)
                _dropdown<int>(
                  hint: 'Categoría',
                  value: _expenseCategoryId,
                  items: [
                    for (final c in catalogs.expenseCategories)
                      DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ],
                  onChanged: (v) => setState(() {
                    _expenseCategoryId = v;
                    _applyFilters();
                  }),
                ),
              if (controller.employees.isNotEmpty)
                _dropdown<String>(
                  hint: 'Empleado',
                  value: _employee,
                  items: [
                    for (final e in controller.employees)
                      DropdownMenuItem(value: e, child: Text(e)),
                  ],
                  onChanged: (v) => setState(() {
                    _employee = v;
                    _applyFilters();
                  }),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: IosCard(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _miniTotal('Ingresos', income, AppColors.incomeDeep),
                _miniTotal('Gastos', expense, AppColors.expenseDeep),
                _miniTotal(
                  'Neto',
                  income - expense,
                  income - expense >= 0
                      ? AppColors.incomeDeep
                      : AppColors.expenseDeep,
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: controller.loading
              ? const Center(child: CircularProgressIndicator())
              : controller.movements.isEmpty
                  ? const EmptyState(
                      icon: Icons.receipt_long_outlined,
                      message: 'No hay movimientos con estos filtros',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                      itemCount: controller.movements.length,
                      itemBuilder: (context, index) {
                        final movement = controller.movements[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: IosCard(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            child: Dismissible(
                              key: ValueKey('movement-${movement.id}'),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: AppColors.expense,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.white,
                                ),
                              ),
                              confirmDismiss: (_) => showDialog<bool>(
                                context: context,
                                builder: (dialogContext) => AlertDialog(
                                  title: const Text('Eliminar movimiento'),
                                  content: Text(
                                    '¿Eliminar '
                                    '"${movement.categoryName ?? 'movimiento'}" '
                                    'de ${Formatters.money(movement.amount)}?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(dialogContext, false),
                                      child: const Text('Cancelar'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(dialogContext, true),
                                      child: const Text('Eliminar'),
                                    ),
                                  ],
                                ),
                              ),
                              onDismissed: (_) =>
                                  controller.delete(movement.id!),
                              child: MovementTile(
                                movement: movement,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => MovementFormScreen(
                                      editing: movement,
                                    ),
                                    fullscreenDialog: true,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _dropdown<T>({
    required String hint,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EDF7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButton<T>(
        value: value,
        hint: Text(hint),
        underline: const SizedBox.shrink(),
        isDense: true,
        items: items,
        onChanged: onChanged,
      ),
    );
  }

  Widget _miniTotal(String label, double value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          Formatters.money(value),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}
