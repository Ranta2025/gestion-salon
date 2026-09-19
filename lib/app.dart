import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'data/repositories/catalog_repository.dart';
import 'data/repositories/client_repository.dart';
import 'data/repositories/finance_repository.dart';
import 'data/repositories/movement_repository.dart';
import 'state/catalog_controller.dart';
import 'state/clients_controller.dart';
import 'state/dashboard_controller.dart';
import 'state/movements_controller.dart';
import 'state/settings_controller.dart';
import 'ui/screens/home_shell.dart';

/// App composition root: repositories (plain) + controllers (notifier).
/// Controllers are created and kicked off in main() before runApp, so
/// their first notifyListeners happens with zero listeners attached.
class GestionSalonApp extends StatelessWidget {
  final SettingsController settings;
  final DashboardController dashboard;
  final MovementsController movements;
  final ClientsController clients;
  final CatalogController catalogs;

  const GestionSalonApp({
    super.key,
    required this.settings,
    required this.dashboard,
    required this.movements,
    required this.clients,
    required this.catalogs,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => MovementRepository()),
        Provider(create: (_) => ClientRepository()),
        Provider(create: (_) => CatalogRepository()),
        Provider(create: (_) => FinanceRepository()),
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: dashboard),
        ChangeNotifierProvider.value(value: movements),
        ChangeNotifierProvider.value(value: clients),
        ChangeNotifierProvider.value(value: catalogs),
      ],
      child: MaterialApp(
        title: 'Gestión Salón',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        locale: const Locale('es'),
        supportedLocales: const [Locale('es'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const HomeShell(),
      ),
    );
  }
}
