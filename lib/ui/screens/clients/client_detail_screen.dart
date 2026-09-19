import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/client_repository.dart';
import '../../../state/clients_controller.dart';
import '../../widgets/ios_card.dart';
import '../../widgets/movement_tile.dart';
import '../../widgets/section_title.dart';

/// Client profile + full visit history (income movements).
class ClientDetailScreen extends StatelessWidget {
  final Client client;

  const ClientDetailScreen({super.key, required this.client});

  Future<void> _edit(BuildContext context) async {
    final nameCtrl = TextEditingController(text: client.name);
    final phoneCtrl = TextEditingController(text: client.phone ?? '');
    final notesCtrl = TextEditingController(text: client.notes ?? '');
    final controller = context.read<ClientsController>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Editar cliente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Nombre'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(hintText: 'Teléfono'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: notesCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Notas'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              await controller.update(
                Client(
                  id: client.id,
                  name: name,
                  phone: phoneCtrl.text.trim().isEmpty
                      ? null
                      : phoneCtrl.text.trim(),
                  notes: notesCtrl.text.trim().isEmpty
                      ? null
                      : notesCtrl.text.trim(),
                  createdAt: client.createdAt,
                ),
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext, true);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (saved == true && context.mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar cliente'),
        content: Text(
          '¿Eliminar a ${client.name}? Sus visitas quedarán '
          'registradas pero sin cliente asociado.',
        ),
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

    if (confirmed == true && context.mounted) {
      await context.read<ClientsController>().delete(client.id!);
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.read<ClientRepository>();

    return Scaffold(
      appBar: AppBar(
        title: Text(client.name),
        actions: [
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _edit(context),
          ),
          IconButton(
            tooltip: 'Eliminar',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context),
          ),
        ],
      ),
      body: FutureBuilder<List<Object?>>(
        future: Future.wait([
          repository.history(client.id!),
          repository.totalSpent(client.id!),
        ]),
        builder: (context, snapshot) {
          final history = snapshot.data?[0] as List<Movement>? ?? const [];
          final total = snapshot.data?[1] as double? ?? 0;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              IosCard(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppColors.accent.withValues(alpha: 0.4),
                      child: Text(
                        client.name.characters.first.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      client.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (client.phone != null)
                      Text(
                        client.phone!,
                        style:
                            const TextStyle(color: AppColors.textSecondary),
                      ),
                    if (client.notes != null && client.notes!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          client.notes!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.income.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        'Total gastado: ${Formatters.money(total)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.incomeDeep,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionTitle('Historial de visitas (${history.length})'),
              const SizedBox(height: 8),
              if (history.isEmpty)
                const IosCard(
                  child: Text(
                    'Sin visitas registradas',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              else
                IosCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    children: [
                      for (final movement in history)
                        MovementTile(movement: movement),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
