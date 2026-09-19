import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'services/notification_service.dart';
import 'state/appointments_controller.dart';
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

  // Notification setup may fail on platforms/emulators without proper
  // support (e.g. missing timezone data or plugin channel) — that must not
  // crash the whole app at launch, so it's isolated in its own try/catch.
  try {
    await NotificationService().init();
  } catch (_) {
    // Reminders won't fire, but the rest of the app remains usable.
  }

  // Initial loads fire before the first frame: notifyListeners with no
  // listeners attached is a no-op, so this is safe and avoids the
  // "notify during build" trap of lazy provider creation.
  final dashboard = DashboardController()..refresh();
  final movements = MovementsController()..refresh();
  final clients = ClientsController()..refresh();
  final catalogs = CatalogController()..refresh();
  final appointments = AppointmentsController()..refresh();

  runApp(
    GestionSalonApp(
      settings: settings,
      dashboard: dashboard,
      movements: movements,
      clients: clients,
      catalogs: catalogs,
      appointments: appointments,
    ),
  );
}
