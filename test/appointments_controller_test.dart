import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_salon/data/db/app_database.dart';
import 'package:gestion_salon/data/models/models.dart';
import 'package:gestion_salon/data/repositories/appointment_repository.dart';
import 'package:gestion_salon/data/repositories/client_repository.dart';
import 'package:gestion_salon/services/notification_service.dart';
import 'package:gestion_salon/state/appointments_controller.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// A [NotificationService] whose scheduling call always throws, simulating a
/// realistic plugin failure (permissions denied, platform channel issues,
/// etc.) so the controller's error handling can be exercised without the
/// real plugin, which cannot run in the unit-test environment.
class _ThrowingNotificationService extends NotificationService {
  @override
  Future<int?> scheduleAppointmentReminder({
    required int appointmentId,
    required DateTime appointmentAt,
    required String clientName,
    String? description,
  }) async {
    throw Exception('plugin failure: notification channel unavailable');
  }
}

void main() {
  late Database db;
  final repository = AppointmentRepository();
  final clients = ClientRepository();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) => AppDatabase.createSchemaForTest(db),
      ),
    );
    AppDatabase.debugSetDatabase(db);
  });

  tearDown(() async {
    await db.close();
  });

  test(
      'add() persists the appointment and refreshes state even when '
      'notification scheduling throws', () async {
    final clientId = await clients.insert(
      Client(name: 'Sofía', createdAt: DateTime.now()),
    );

    final controller = AppointmentsController(
      repository: repository,
      notificationService: _ThrowingNotificationService(),
    );

    final appointmentDate = DateTime.now().add(const Duration(days: 2));

    // Must not throw: a notification-scheduling failure must not propagate
    // out of add() and must not prevent the appointment from being saved.
    final id = await controller.add(
      Appointment(
        clientId: clientId,
        dateTime: appointmentDate,
        createdAt: DateTime.now(),
      ),
      clientName: 'Sofía',
    );

    final persisted = await repository.byId(id);
    expect(persisted, isNotNull);
    expect(persisted!.clientId, clientId);
    // Scheduling failed, so no notification id should have been persisted.
    expect(persisted.notificationId, isNull);

    // The controller's in-memory state must reflect the persisted appointment
    // (refresh() must still run after the scheduling failure).
    expect(controller.upcoming.any((a) => a.id == id), isTrue);
  });
}
