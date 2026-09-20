import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_helpers.dart';
import '../../../data/models/models.dart';
import '../../../state/appointments_controller.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/ios_card.dart';

enum _AppointmentAction { complete, cancel, delete }

/// Appointment history: every appointment regardless of status, newest
/// first (as returned by `AppointmentsController.history`). Tapping a row
/// opens a bottom sheet of actions gated by the appointment's current
/// status. Adding a new appointment is not this screen's job — the tab's
/// FAB opens `AppointmentFormScreen` directly.
class AppointmentsScreen extends StatelessWidget {
  const AppointmentsScreen({super.key});

  String _statusLabel(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.scheduled:
        return 'Programada';
      case AppointmentStatus.cancelled:
        return 'Cancelada';
      case AppointmentStatus.completed:
        return 'Realizada';
    }
  }

  Color _statusColor(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.scheduled:
        return AppColors.info;
      case AppointmentStatus.cancelled:
        return AppColors.expenseDeep;
      case AppointmentStatus.completed:
        return AppColors.incomeDeep;
    }
  }

  Future<void> _openActions(
    BuildContext context,
    Appointment appointment,
  ) async {
    final action = await showModalBottomSheet<_AppointmentAction>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                appointment.clientName ?? 'Cliente',
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              if (appointment.status == AppointmentStatus.scheduled) ...[
                _ActionTile(
                  icon: Icons.check_circle_outline,
                  label: 'Marcar como realizada',
                  color: AppColors.incomeDeep,
                  onTap: () =>
                      Navigator.pop(context, _AppointmentAction.complete),
                ),
                const SizedBox(height: 8),
                _ActionTile(
                  icon: Icons.event_busy_outlined,
                  label: 'Cancelar cita',
                  color: AppColors.expenseDeep,
                  onTap: () =>
                      Navigator.pop(context, _AppointmentAction.cancel),
                ),
                const SizedBox(height: 8),
              ],
              _ActionTile(
                icon: Icons.delete_outline,
                label: 'Eliminar del historial',
                color: AppColors.textSecondary,
                onTap: () => Navigator.pop(context, _AppointmentAction.delete),
              ),
            ],
          ),
        ),
      ),
    );

    if (action == null || !context.mounted) return;

    final id = appointment.id;
    if (id == null) return;
    final controller = context.read<AppointmentsController>();

    switch (action) {
      case _AppointmentAction.complete:
        await controller.complete(id);
        break;
      case _AppointmentAction.cancel:
        await controller.cancel(id);
        break;
      case _AppointmentAction.delete:
        if (!context.mounted) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Eliminar cita'),
            content: Text(
              '¿Eliminar del historial la cita de '
              '"${appointment.clientName ?? 'este cliente'}"?',
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
        if (confirmed == true) await controller.delete(id);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppointmentsController>();

    if (controller.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.history.isEmpty) {
      return const EmptyState(
        icon: Icons.event_note_outlined,
        message: 'Todavía no agendaste ninguna cita',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      itemCount: controller.history.length,
      itemBuilder: (context, index) {
        final appointment = controller.history[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: IosCard(
            onTap: () => _openActions(context, appointment),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment.clientName ?? 'Cliente eliminado',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${DateHelpers.humanShort(appointment.dateTime)} · '
                        '${DateHelpers.humanTime(appointment.dateTime)}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (appointment.description != null &&
                          appointment.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          appointment.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _StatusBadge(
                  label: _statusLabel(appointment.status),
                  color: _statusColor(appointment.status),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
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
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
