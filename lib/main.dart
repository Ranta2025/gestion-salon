import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'state/catalog_controller.dart';
import 'state/clients_controller.dart';
import 'state/dashboard_controller.dart';
import 'state/movements_controller.dart';
import 'state/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');

  final settings = SettingsController();
  await settings.load();

  // Initial loads fire before the first frame: notifyListeners with no
  // listeners attached is a no-op, so this is safe and avoids the
  // "notify during build" trap of lazy provider creation.
  final dashboard = DashboardController()..refresh();
  final movements = MovementsController()..refresh();
  final clients = ClientsController()..refresh();
  final catalogs = CatalogController()..refresh();

  runApp(
    GestionSalonApp(
      settings: settings,
      dashboard: dashboard,
      movements: movements,
      clients: clients,
      catalogs: catalogs,
    ),
  );
}
