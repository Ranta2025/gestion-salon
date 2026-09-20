import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import 'appointments/appointment_form_screen.dart';
import 'appointments/appointments_screen.dart';
import 'catalogs/catalogs_screen.dart';
import 'clients/clients_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'movements/movement_form_screen.dart';
import 'movements/movements_screen.dart';
import 'reports/reports_screen.dart';
import 'settings/settings_screen.dart';

/// Bottom-tab navigation with the quick-add "+" floating button.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _titles = [
    'Gestión Salón',
    'Movimientos',
    'Clientes',
    'Reportes',
    'Citas',
    'Ajustes',
  ];

  static const _screens = [
    DashboardScreen(),
    MovementsScreen(),
    ClientsScreen(),
    ReportsScreen(),
    AppointmentsScreen(),
    SettingsScreen(),
  ];

  Future<void> _quickAdd() async {
    final type = await showModalBottomSheet<MovementType>(
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
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '¿Qué querés registrar?',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _QuickOption(
                      label: 'Ingreso',
                      icon: Icons.arrow_upward,
                      color: AppColors.income,
                      textColor: AppColors.incomeDeep,
                      onTap: () =>
                          Navigator.pop(context, MovementType.income),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickOption(
                      label: 'Gasto',
                      icon: Icons.arrow_downward,
                      color: AppColors.expense,
                      textColor: AppColors.expenseDeep,
                      onTap: () =>
                          Navigator.pop(context, MovementType.expense),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (type == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MovementFormScreen(initialType: type),
        fullscreenDialog: true,
      ),
    );
  }

  Future<void> _addAppointment() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const AppointmentFormScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  Widget? _buildFab() {
    if (_index <= 1) {
      return FloatingActionButton(
        onPressed: _quickAdd,
        tooltip: 'Agregar movimiento',
        child: const Icon(Icons.add, size: 28),
      );
    }
    if (_index == 4) {
      return FloatingActionButton(
        onPressed: _addAppointment,
        tooltip: 'Agendar cita',
        child: const Icon(Icons.add, size: 28),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: _index == 0
            ? [
                IconButton(
                  tooltip: 'Catálogos',
                  icon: const Icon(Icons.dashboard_customize_outlined),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CatalogsScreen(),
                    ),
                  ),
                ),
              ]
            : null,
      ),
      body: IndexedStack(index: _index, children: _screens),
      floatingActionButton: _buildFab(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Movimientos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Clientes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart),
            label: 'Reportes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_available_outlined),
            activeIcon: Icon(Icons.event_available),
            label: 'Citas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }
}

class _QuickOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  const _QuickOption({
    required this.label,
    required this.icon,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Icon(icon, color: textColor, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
