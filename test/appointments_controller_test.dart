import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_salon/data/db/app_database.dart';
import 'package:gestion_salon/data/models/models.dart';
import 'package:gestion_salon/data/repositories/appointment_repository.dart';
import 'package:gestion_salon/data/repositories/client_repository.dart';
import 'package:gestion_salon/data/repositories/movement_repository.dart';
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

/// A [MovementRepository] whose insert always throws, simulating a real
/// persistence failure — used to prove that a failed charge insert must not
/// leave the appointment marked as completed.
class _ThrowingMovementRepository extends MovementRepository {
  @override
  Future<int> insert(Movement movement, {DatabaseExecutor? executor}) async {
    throw Exception('disk failure: could not insert movement');
  }
}

void main() {
  late Database db;
  final repository = AppointmentRepository();
  final clients = ClientRepository();
  final movements = MovementRepository();

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

    await controller.complete(id, amountCharged: 1500);

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

  test(
      'update() persists changed client, date/time and description without '
      'touching status', () async {
    final clientId = await clients.insert(
      Client(name: 'Carla', createdAt: DateTime.now()),
    );
    final newClientId = await clients.insert(
      Client(name: 'Diana', createdAt: DateTime.now()),
    );
    final controller = AppointmentsController(
      repository: repository,
      notificationService: _FakeNotificationService(),
    );

    final originalDate = DateTime.now().add(const Duration(days: 3));
    final id = await controller.add(
      Appointment(
        clientId: clientId,
        dateTime: originalDate,
        description: 'Corte',
        createdAt: DateTime.now(),
      ),
      clientName: 'Carla',
    );

    final stored = (await repository.byId(id))!;
    final newDate = originalDate.add(const Duration(days: 1));

    await controller.update(
      Appointment(
        id: stored.id,
        clientId: newClientId,
        dateTime: newDate,
        description: 'Corte y color',
        createdAt: stored.createdAt,
      ),
      clientName: 'Diana',
    );

    final persisted = await repository.byId(id);
    expect(persisted!.clientId, newClientId);
    expect(persisted.description, 'Corte y color');
    expect(persisted.status, AppointmentStatus.scheduled);
    expect(
      persisted.dateTime.difference(newDate).inSeconds.abs(),
      lessThan(1),
    );
  });

  test(
      'update() changing dateTime on an appointment with a live reminder '
      'cancels the old reminder and reschedules a new one', () async {
    final clientId = await clients.insert(
      Client(name: 'Elena', createdAt: DateTime.now()),
    );
    final notificationService = _FakeNotificationService();
    final controller = AppointmentsController(
      repository: repository,
      notificationService: notificationService,
    );

    final originalDate = DateTime.now().add(const Duration(days: 3));
    final id = await controller.add(
      Appointment(
        clientId: clientId,
        dateTime: originalDate,
        createdAt: DateTime.now(),
      ),
      clientName: 'Elena',
    );

    final stored = (await repository.byId(id))!;
    expect(stored.notificationId, 999);

    final newDate = originalDate.add(const Duration(days: 2));
    await controller.update(
      Appointment(
        id: stored.id,
        clientId: clientId,
        dateTime: newDate,
        createdAt: stored.createdAt,
      ),
      clientName: 'Elena',
    );

    expect(notificationService.cancelledIds, contains(999));
    final persisted = await repository.byId(id);
    expect(persisted!.notificationId, 999);
    expect(
      persisted.dateTime.difference(newDate).inSeconds.abs(),
      lessThan(1),
    );
  });

  test(
      'update() leaves notificationId untouched when dateTime does not '
      'change', () async {
    final clientId = await clients.insert(
      Client(name: 'Flor', createdAt: DateTime.now()),
    );
    final notificationService = _FakeNotificationService();
    final controller = AppointmentsController(
      repository: repository,
      notificationService: notificationService,
    );

    final date = DateTime.now().add(const Duration(days: 3));
    final id = await controller.add(
      Appointment(
        clientId: clientId,
        dateTime: date,
        createdAt: DateTime.now(),
      ),
      clientName: 'Flor',
    );

    final stored = (await repository.byId(id))!;
    expect(stored.notificationId, 999);

    await controller.update(
      Appointment(
        id: stored.id,
        clientId: clientId,
        dateTime: stored.dateTime,
        description: 'Retoque',
        createdAt: stored.createdAt,
      ),
      clientName: 'Flor',
    );

    expect(notificationService.cancelledIds, isEmpty);
    final persisted = await repository.byId(id);
    expect(persisted!.notificationId, 999);
    expect(persisted.description, 'Retoque');
  });

  test(
      'complete(amountCharged:) inserts exactly one income Movement with the '
      'right amount/clientId/date and marks the appointment completed',
      () async {
    final clientId = await clients.insert(
      Client(name: 'Gaby', createdAt: DateTime.now()),
    );
    final notificationService = _FakeNotificationService();
    final controller = AppointmentsController(
      repository: repository,
      notificationService: notificationService,
      movementRepository: movements,
    );

    final appointmentDate = DateTime.now().add(const Duration(days: 1));
    final id = await controller.add(
      Appointment(
        clientId: clientId,
        dateTime: appointmentDate,
        description: 'Corte y color',
        createdAt: DateTime.now(),
      ),
      clientName: 'Gaby',
    );

    final before = await movements.query();
    expect(before, isEmpty);

    await controller.complete(id, amountCharged: 2500);

    final persisted = await repository.byId(id);
    expect(persisted!.status, AppointmentStatus.completed);
    expect(persisted.notificationId, isNull);
    expect(notificationService.cancelledIds, contains(999));

    final createdMovements = await movements.query();
    expect(createdMovements, hasLength(1));
    final movement = createdMovements.single;
    expect(movement.type, MovementType.income);
    expect(movement.amount, 2500);
    expect(movement.clientId, clientId);
    expect(
      movement.date.difference(appointmentDate).inSeconds.abs(),
      lessThan(1),
    );
    expect(movement.note, contains('Gaby'));
    expect(movement.note, contains('Corte y color'));
  });

  test(
      'complete() does not mark the appointment completed when the movement '
      'insert fails', () async {
    final clientId = await clients.insert(
      Client(name: 'Hilda', createdAt: DateTime.now()),
    );
    final controller = AppointmentsController(
      repository: repository,
      notificationService: _FakeNotificationService(),
      movementRepository: _ThrowingMovementRepository(),
    );

    final id = await controller.add(
      Appointment(
        clientId: clientId,
        dateTime: DateTime.now().add(const Duration(days: 1)),
        createdAt: DateTime.now(),
      ),
      clientName: 'Hilda',
    );

    await expectLater(
      () => controller.complete(id, amountCharged: 1000),
      throwsException,
    );

    final persisted = await repository.byId(id);
    expect(persisted!.status, AppointmentStatus.scheduled);
    final createdMovements = await movements.query();
    expect(createdMovements, isEmpty);
  });
}
