import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_helpers.dart';
import '../../../core/utils/labels.dart';
import '../../../data/models/models.dart';
import '../../../state/catalog_controller.dart';
import '../../../state/clients_controller.dart';
import '../../../state/dashboard_controller.dart';
import '../../../state/movements_controller.dart';

/// Add/edit form for one movement. Type is locked while editing so a
/// service never ends up pointing at an expense category (or vice versa).
class MovementFormScreen extends StatefulWidget {
  final MovementType initialType;
  final Movement? editing;

  const MovementFormScreen({
    super.key,
    this.initialType = MovementType.income,
    this.editing,
  });

  @override
  State<MovementFormScreen> createState() => _MovementFormScreenState();
}

class _MovementFormScreenState extends State<MovementFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _employeeCtrl = TextEditingController();
  final _supplierCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  late MovementType _type;
  late DateTime _date;
  int? _serviceId;
  int? _expenseCategoryId;
  int? _clientId;
  String _paymentMethod = 'efectivo';
  bool _saving = false;

  bool get _isEditing => widget.editing != null;
  bool get _isIncome => _type == MovementType.income;

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    _type = editing?.type ?? widget.initialType;
    _date = editing?.date ?? DateTime.now();
    _serviceId = editing?.serviceId;
    _expenseCategoryId = editing?.expenseCategoryId;
    _clientId = editing?.clientId;
    _paymentMethod = editing?.paymentMethod ?? 'efectivo';
    if (editing != null) {
      _amountCtrl.text = editing.amount.toStringAsFixed(2);
      _employeeCtrl.text = editing.employee ?? '';
      _supplierCtrl.text = editing.supplier ?? '';
      _noteCtrl.text = editing.note ?? '';
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _employeeCtrl.dispose();
    _supplierCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  double? get _parsedAmount {
    final raw = _amountCtrl.text.trim().replaceAll(',', '.');
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      locale: const Locale('es'),
    );
    if (picked != null) {
      setState(() {
        _date = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _date.hour,
          _date.minute,
        );
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    if (picked != null) {
      setState(() {
        _date = DateTime(
          _date.year,
          _date.month,
          _date.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  Future<void> _createClient() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final created = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nuevo cliente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Nombre'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(hintText: 'Teléfono (opcional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final id = await dialogContext.read<ClientsController>().save(
                    Client(
                      name: name,
                      phone: phoneCtrl.text.trim().isEmpty
                          ? null
                          : phoneCtrl.text.trim(),
                      createdAt: DateTime.now(),
                    ),
                  );
              if (dialogContext.mounted) Navigator.pop(dialogContext, id);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (created != null && mounted) {
      setState(() => _clientId = created);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final amount = _parsedAmount;
    if (amount == null || amount <= 0) {
      _showError('Ingresá un monto mayor a cero');
      return;
    }
    if (_isIncome && _serviceId == null) {
      _showError('Elegí un servicio');
      return;
    }
    if (!_isIncome && _expenseCategoryId == null) {
      _showError('Elegí una categoría');
      return;
    }

    setState(() => _saving = true);
    try {
      final movements = context.read<MovementsController>();
      final employee = _employeeCtrl.text.trim();
      final supplier = _supplierCtrl.text.trim();
      final note = _noteCtrl.text.trim();

      final movement = Movement(
        id: widget.editing?.id,
        type: _type,
        amount: amount,
        date: _date,
        serviceId: _isIncome ? _serviceId : null,
        expenseCategoryId: _isIncome ? null : _expenseCategoryId,
        clientId: _isIncome ? _clientId : null,
        employee: _isIncome && employee.isNotEmpty ? employee : null,
        supplier: !_isIncome && supplier.isNotEmpty ? supplier : null,
        paymentMethod: _paymentMethod,
        note: note.isEmpty ? null : note,
        createdAt: widget.editing?.createdAt ?? DateTime.now(),
      );

      if (_isEditing) {
        await movements.update(movement);
      } else {
        await movements.add(movement);
      }
      if (!mounted) return;
      await context.read<DashboardController>().refresh();
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalogs = context.watch<CatalogController>();
    final clients = context.watch<ClientsController>();
    final employees = context.watch<MovementsController>().employees;

    final activeServices = catalogs.services.where((s) => s.active).toList();
    final activeCategories =
        catalogs.expenseCategories.where((c) => c.active).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing
              ? 'Editar ${_isIncome ? 'ingreso' : 'gasto'}'
              : 'Nuevo ${_isIncome ? 'ingreso' : 'gasto'}',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!_isEditing) ...[
              _TypeSwitcher(
                type: _type,
                onChanged: (type) => setState(() => _type = type),
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
              decoration: const InputDecoration(
                hintText: '0.00',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _PickerTile(
                    icon: Icons.calendar_today_outlined,
                    label: DateHelpers.humanShort(_date),
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PickerTile(
                    icon: Icons.access_time,
                    label: DateHelpers.humanTime(_date),
                    onTap: _pickTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isIncome)
              DropdownButtonFormField<int>(
                initialValue: _serviceId,
                decoration: const InputDecoration(
                  labelText: 'Servicio',
                  prefixIcon: Icon(Icons.content_cut),
                ),
                items: [
                  for (final service in activeServices)
                    DropdownMenuItem(
                      value: service.id,
                      child: Text(
                        service.price > 0
                            ? '${service.name} — ${service.price.toStringAsFixed(2)}'
                            : service.name,
                      ),
                    ),
                ],
                onChanged: (id) {
                  setState(() => _serviceId = id);
                  // Autocomplete amount from the saved service price.
                  if (id != null && _amountCtrl.text.trim().isEmpty) {
                    final service =
                        activeServices.where((s) => s.id == id).firstOrNull;
                    if (service != null && service.price > 0) {
                      _amountCtrl.text = service.price.toStringAsFixed(2);
                    }
                  }
                },
              )
            else
              DropdownButtonFormField<int>(
                initialValue: _expenseCategoryId,
                decoration: const InputDecoration(
                  labelText: 'Categoría',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: [
                  for (final category in activeCategories)
                    DropdownMenuItem(
                      value: category.id,
                      child: Text(category.name),
                    ),
                ],
                onChanged: (id) => setState(() => _expenseCategoryId = id),
              ),
            const SizedBox(height: 12),
            if (_isIncome) ...[
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _clientId,
                      decoration: const InputDecoration(
                        labelText: 'Cliente (opcional)',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      items: [
                        for (final client in clients.clients)
                          DropdownMenuItem(
                            value: client.id,
                            child: Text(client.name),
                          ),
                      ],
                      onChanged: (id) => setState(() => _clientId = id),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Nuevo cliente',
                    onPressed: _createClient,
                    icon: const Icon(Icons.person_add_alt,
                        color: AppColors.accentDeep),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _employeeCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Empleado (opcional)',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              if (employees.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      for (final employee in employees)
                        ActionChip(
                          label: Text(employee),
                          onPressed: () => _employeeCtrl.text = employee,
                        ),
                    ],
                  ),
                ),
            ] else ...[
              TextFormField(
                controller: _supplierCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Proveedor (opcional)',
                  prefixIcon: Icon(Icons.storefront_outlined),
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Método de pago',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final method in Labels.paymentMethods)
                  ChoiceChip(
                    label: Text(Labels.payment(method)),
                    selected: _paymentMethod == method,
                    showCheckmark: false,
                    onSelected: (_) =>
                        setState(() => _paymentMethod = method),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteCtrl,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nota (opcional)',
                prefixIcon: Icon(Icons.notes),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_isEditing ? 'Guardar cambios' : 'Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeSwitcher extends StatelessWidget {
  final MovementType type;
  final ValueChanged<MovementType> onChanged;

  const _TypeSwitcher({required this.type, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EDF7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          for (final option in MovementType.values)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(option),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: type == option ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      option == MovementType.income ? 'Ingreso' : 'Gasto',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: type == option
                            ? (option == MovementType.income
                                ? AppColors.incomeDeep
                                : AppColors.expenseDeep)
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PickerTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF0EDF7),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
