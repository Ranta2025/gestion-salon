import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../state/settings_controller.dart';
import '../../widgets/ios_card.dart';
import '../../widgets/section_title.dart';
import '../cash_close/cash_close_history_screen.dart';
import '../catalogs/catalogs_screen.dart';
import 'goal_sheet.dart';

/// Settings: currency, monthly goal, catalogs, cash-close history,
/// local backup/restore. Everything stays on-device.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _editCurrency(SettingsController controller) async {
    final symbolCtrl = TextEditingController(text: controller.currencySymbol);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Símbolo de moneda'),
        content: TextField(
          controller: symbolCtrl,
          autofocus: true,
          maxLength: 4,
          decoration: const InputDecoration(hintText: r'$'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              await controller.setCurrency(symbolCtrl.text);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _runBackupAction(
    Future<void> Function() action,
  ) async {
    final controller = context.read<SettingsController>();
    await action();
    if (!mounted) return;
    final message = controller.lastMessage;
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SettingsController>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        const SectionTitle('Negocio'),
        const SizedBox(height: 8),
        IosCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.payments_outlined),
                title: const Text('Moneda'),
                subtitle: Text('Símbolo actual: ${controller.currencySymbol}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _editCurrency(controller),
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Meta mensual'),
                subtitle: const Text('Objetivo de ingresos del mes en curso'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showGoalSheet(context),
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.dashboard_customize_outlined),
                title: const Text('Catálogos'),
                subtitle: const Text('Servicios y categorías de gasto'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CatalogsScreen(),
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.lock_outline),
                title: const Text('Cierres de caja'),
                subtitle: const Text('Historial de días cerrados'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CashCloseHistoryScreen(),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const SectionTitle('Respaldo de datos'),
        const SizedBox(height: 8),
        IosCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'El respaldo es un archivo JSON con TODOS tus datos. '
                'Guardalo donde quieras (Drive, WhatsApp, PC) y '
                'restauralo cuando cambies de teléfono.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.upload_outlined),
                      label: const Text('Exportar'),
                      onPressed: controller.busy
                          ? null
                          : () => _runBackupAction(
                                controller.exportBackup,
                              ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Restaurar'),
                      onPressed: controller.busy
                          ? null
                          : () => _runBackupAction(
                                controller.importBackup,
                              ),
                    ),
                  ),
                ],
              ),
              if (controller.busy)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        IosCard(
          child: Row(
            children: [
              Icon(
                Icons.wifi_off_outlined,
                color: AppColors.incomeDeep,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Gestión Salón funciona 100% sin internet. '
                  'Tus datos viven en este dispositivo.',
                  style: TextStyle(
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
}
