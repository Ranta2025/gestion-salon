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

/// A [NotificationService] whose scheduling call always succeeds with a
/// fixed notification id, and which records every id passed to
/// [cancelReminder] — used to verify that cancelling/completing an
/// appointment actually cancels its live reminder.
class _FakeNotificationService extends NotificationService {
  final List<int> cancelledIds = [];

  @override
  Future<int?> scheduleAppointmentReminder({
    required int appointmentId,
    required DateTime appointmentAt,
    required String clientName,
    String? description,
  }) async =>
      999;

  @override
  Future<void> cancelReminder(int notificationId) async {
    cancelledIds.add(notificationId);
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

  test(
      'cancel() sets status to cancelled, cancels the live reminder, clears '
      'notificationId, and moves the appointment from upcoming to history',
      () async {
    final clientId = await clients.insert(
      Client(name: 'Ana', createdAt: DateTime.now()),
    );
    final notificationService = _FakeNotificationService();
    final controller = AppointmentsController(
      repository: repository,
      notificationService: notificationService,
    );

    final id = await controller.add(
      Appointment(
        clientId: clientId,
        dateTime: DateTime.now().add(const Duration(days: 1)),
        createdAt: DateTime.now(),
      ),
      clientName: 'Ana',
    );

    final beforeCancel = await repository.byId(id);
    expect(beforeCancel!.notificationId, 999);
    expect(controller.upcoming.any((a) => a.id == id), isTrue);

    await controller.cancel(id);

    final persisted = await repository.byId(id);
    expect(persisted!.status, AppointmentStatus.cancelled);
    expect(persisted.notificationId, isNull);
    expect(notificationService.cancelledIds, contains(999));

    expect(controller.upcoming.any((a) => a.id == id), isFalse);
    expect(
      controller.history.any(
        (a) => a.id == id && a.status == AppointmentStatus.cancelled,
      ),
      isTrue,
    );
  });

  test(
      'complete() sets status to completed, cancels the live reminder, '
      'clears notificationId, and moves the appointment from upcoming to '
      'history', () async {
    final clientId = await clients.insert(
      Client(name: 'Bea', createdAt: DateTime.now()),
    );
    final notificationService = _FakeNotificationService();
    final controller = AppointmentsController(
      repository: repository,
      notificationService: notificationService,
    );

    final id = await controller.add(
      Appointment(
        clientId: clientId,
        dateTime: DateTime.now().add(const Duration(days: 1)),
        createdAt: DateTime.now(),
      ),
      clientName: 'Bea',
    );

    final beforeComplete = await repository.byId(id);
    expect(beforeComplete!.notificationId, 999);
    expect(controller.upcoming.any((a) => a.id == id), isTrue);

    await controller.complete(id);

    final persisted = await repository.byId(id);
    expect(persisted!.status, AppointmentStatus.completed);
    expect(persisted.notificationId, isNull);
    expect(notificationService.cancelledIds, contains(999));

    expect(controller.upcoming.any((a) => a.id == id), isFalse);
    expect(
      controller.history.any(
        (a) => a.id == id && a.status == AppointmentStatus.completed,
      ),
      isTrue,
    );
  });
}
