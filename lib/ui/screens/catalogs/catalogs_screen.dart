import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/models.dart';
import '../../../state/catalog_controller.dart';
import '../../widgets/ios_card.dart';

/// Configurable catalogs: services (with saved price) and expense
/// categories. Deactivating keeps history intact.
class CatalogsScreen extends StatelessWidget {
  const CatalogsScreen({super.key});

  Future<void> _serviceDialog(
    BuildContext context, {
    ServiceItem? existing,
  }) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final priceCtrl = TextEditingController(
      text: existing != null && existing.price > 0
          ? existing.price.toStringAsFixed(2)
          : '',
    );
    final controller = context.read<CatalogController>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(existing == null ? 'Nuevo servicio' : 'Editar servicio'),
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
              controller: priceCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                hintText: 'Precio (opcional, para autocompletar)',
              ),
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
              final price = double.tryParse(
                    priceCtrl.text.trim().replaceAll(',', '.'),
                  ) ??
                  0;
              await controller.saveService(
                ServiceItem(
                  id: existing?.id,
                  name: name,
                  price: price,
                  active: existing?.active ?? true,
                ),
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _categoryDialog(
    BuildContext context, {
    ExpenseCategory? existing,
  }) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final controller = context.read<CatalogController>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(existing == null ? 'Nueva categoría' : 'Editar categoría'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Nombre'),
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
              await controller.saveExpenseCategory(
                ExpenseCategory(
                  id: existing?.id,
                  name: name,
                  active: existing?.active ?? true,
                ),
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context, {
    required String what,
    required Future<void> Function() onDelete,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar'),
        content: Text('¿Eliminar "$what"? Los movimientos existentes '
            'conservan su historial.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed == true) await onDelete();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CatalogController>();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Catálogos'),
          bottom: const TabBar(
            labelColor: AppColors.accentDeep,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.accentDeep,
            tabs: [
              Tab(text: 'Servicios'),
              Tab(text: 'Categorías de gasto'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _servicesTab(context, controller),
            _categoriesTab(context, controller),
          ],
        ),
      ),
    );
  }

  Widget _servicesTab(BuildContext context, CatalogController controller) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final service in controller.services)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: IosCard(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  service.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: service.active
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
                subtitle: service.price > 0
                    ? Text(Formatters.money(service.price))
                    : const Text('Sin precio guardado'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: service.active,
                      activeTrackColor: AppColors.income,
                      onChanged: (_) => controller.toggleService(service),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () =>
                          _serviceDialog(context, existing: service),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () => _confirmDelete(
                        context,
                        what: service.name,
                        onDelete: () =>
                            controller.deleteService(service.id!),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        FilledButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Agregar servicio'),
          onPressed: () => _serviceDialog(context),
        ),
      ],
    );
  }

  Widget _categoriesTab(
    BuildContext context,
    CatalogController controller,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final category in controller.expenseCategories)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: IosCard(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  category.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () =>
                          _categoryDialog(context, existing: category),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () => _confirmDelete(
                        context,
                        what: category.name,
                        onDelete: () =>
                            controller.deleteExpenseCategory(category.id!),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        FilledButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Agregar categoría'),
          onPressed: () => _categoryDialog(context),
        ),
      ],
    );
  }
}
