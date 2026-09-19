import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_helpers.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/finance_repository.dart';
import '../../../data/repositories/movement_repository.dart';
import '../../../services/export_service.dart';
import '../../../state/catalog_controller.dart';
import '../../../state/movements_controller.dart';
import '../../widgets/chart_capture.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/income_expense_pie.dart';
import '../../widgets/ios_card.dart';
import '../../widgets/section_title.dart';
import '../../widgets/trend_chart.dart';

/// Filterable report with PDF/CSV export. Charts are wrapped in
/// [RepaintBoundary] so the PDF embeds exactly what the user sees.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _pieKey = GlobalKey();
  final _trendKey = GlobalKey();
  final _exporter = ExportService();

  late DateTimeRange _range;
  MovementType? _type;
  int? _serviceId;
  int? _expenseCategoryId;
  String? _employee;

  List<Movement> _movements = const [];
  List<MonthPoint> _trend = const [];
  bool _loading = true;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _range = DateHelpers.currentMonth();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  String get _periodLabel => DateHelpers.rangeLabel(_range);

  double get _income => _movements
      .where((m) => m.isIncome)
      .fold(0.0, (sum, m) => sum + m.amount);

  double get _expense => _movements
      .where((m) => !m.isIncome)
      .fold(0.0, (sum, m) => sum + m.amount);

  Future<void> _load() async {
    setState(() => _loading = true);
    final movementsRepo = context.read<MovementRepository>();
    final financeRepo = context.read<FinanceRepository>();
    final results = await Future.wait([
      movementsRepo.query(
        filter: MovementFilter(
          range: _range,
          type: _type,
          serviceId: _serviceId,
          expenseCategoryId: _expenseCategoryId,
          employee: _employee,
        ),
      ),
      financeRepo.monthlyTrend(6),
    ]);
    if (!mounted) return;
    setState(() {
      _movements = results[0] as List<Movement>;
      _trend = results[1] as List<MonthPoint>;
      _loading = false;
    });
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: _range,
      locale: const Locale('es'),
    );
    if (picked != null) {
      setState(() => _range = picked);
      await _load();
    }
  }

  Future<void> _exportPdf() async {
    setState(() => _exporting = true);
    try {
      // Let charts settle into the repaint boundaries before capturing.
      await Future<void>.delayed(const Duration(milliseconds: 80));
      final piePng = await captureBoundaryPng(_pieKey);
      final trendPng = await captureBoundaryPng(_trendKey);
      await _exporter.sharePdf(
        periodLabel: _periodLabel,
        totals: Totals(income: _income, expense: _expense),
        movements: _movements,
        piePng: piePng,
        trendPng: trendPng,
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportCsv() async {
    setState(() => _exporting = true);
    try {
      await _exporter.shareCsv(
        movements: _movements,
        periodLabel: _periodLabel,
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalogs = context.watch<CatalogController>();
    final employees = context.watch<MovementsController>().employees;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              avatar: const Icon(Icons.date_range, size: 16),
              label: Text(_periodLabel),
              onPressed: _pickRange,
            ),
            for (final option in [null, ...MovementType.values])
              ChoiceChip(
                label: Text(option == null ? 'Todos' : option.labelEs),
                selected: _type == option,
                showCheckmark: false,
                onSelected: (_) => setState(() {
                  _type = option;
                  _serviceId = null;
                  _expenseCategoryId = null;
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
                onChanged: (v) => setState(() => _serviceId = v),
              ),
            if (_type == MovementType.expense)
              _dropdown<int>(
                hint: 'Categoría',
                value: _expenseCategoryId,
                items: [
                  for (final c in catalogs.expenseCategories)
                    DropdownMenuItem(value: c.id, child: Text(c.name)),
                ],
                onChanged: (v) => setState(() => _expenseCategoryId = v),
              ),
            if (employees.isNotEmpty)
              _dropdown<String>(
                hint: 'Empleado',
                value: _employee,
                items: [
                  for (final e in employees)
                    DropdownMenuItem(value: e, child: Text(e)),
                ],
                onChanged: (v) => setState(() => _employee = v),
              ),
            TextButton.icon(
              icon: const Icon(Icons.filter_alt_outlined, size: 18),
              label: const Text('Aplicar'),
              onPressed: _load,
            ),
          ],
        ),
        const SizedBox(height: 12),
        IosCard(
          child: Column(
            children: [
              RepaintBoundary(
                key: _pieKey,
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(8),
                  child: IncomeExpensePie(
                    income: _income,
                    expense: _expense,
                    size: 180,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _total('Ingresos', _income, AppColors.incomeDeep),
                  _total('Gastos', _expense, AppColors.expenseDeep),
                  _total(
                    'Neto',
                    _income - _expense,
                    _income - _expense >= 0
                        ? AppColors.incomeDeep
                        : AppColors.expenseDeep,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        IosCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('Tendencia'),
              const SizedBox(height: 12),
              RepaintBoundary(
                key: _trendKey,
                child: Container(
                  color: Colors.white,
                  child: TrendChart(points: _trend),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Exportar PDF'),
                onPressed: _exporting || _loading ? null : _exportPdf,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.table_chart_outlined),
                label: const Text('Exportar CSV'),
                onPressed: _exporting || _loading ? null : _exportCsv,
              ),
            ),
          ],
        ),
        if (_exporting)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Center(child: CircularProgressIndicator()),
          ),
        const SizedBox(height: 12),
        SectionTitle('Movimientos (${_movements.length})'),
        const SizedBox(height: 8),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_movements.isEmpty)
          const EmptyState(
            icon: Icons.bar_chart_outlined,
            message: 'No hay movimientos en este período',
          )
        else
          IosCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              children: [
                for (final movement in _movements.take(50))
                  _ReportRow(movement: movement),
                if (_movements.length > 50)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      'Mostrando 50 de ${_movements.length} — '
                      'el PDF/CSV incluye todos',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
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

  Widget _total(String label, double value, Color color) {
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
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _ReportRow extends StatelessWidget {
  final Movement movement;

  const _ReportRow({required this.movement});

  @override
  Widget build(BuildContext context) {
    final color =
        movement.isIncome ? AppColors.incomeDeep : AppColors.expenseDeep;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '${DateHelpers.humanShort(movement.date)} '
              '${DateHelpers.humanTime(movement.date)}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              movement.categoryName ?? movement.type.labelEs,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            Formatters.money(movement.amount),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
