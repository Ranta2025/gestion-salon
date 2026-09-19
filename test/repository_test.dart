import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_salon/core/utils/date_helpers.dart';
import 'package:gestion_salon/data/db/app_database.dart';
import 'package:gestion_salon/data/models/models.dart';
import 'package:gestion_salon/data/repositories/appointment_repository.dart';
import 'package:gestion_salon/data/repositories/catalog_repository.dart';
import 'package:gestion_salon/data/repositories/client_repository.dart';
import 'package:gestion_salon/data/repositories/finance_repository.dart';
import 'package:gestion_salon/data/repositories/movement_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Repository tests run against a real (in-memory) SQLite database with
/// the production schema and seed data — no mocks, no shortcuts.
void main() {
  late Database db;
  final movements = MovementRepository();
  final clients = ClientRepository();
  final catalogs = CatalogRepository();
  final finance = FinanceRepository();
  final appointments = AppointmentRepository();

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

  Movement income({
    required double amount,
    required DateTime date,
    int? serviceId,
    int? clientId,
    String? employee,
  }) =>
      Movement(
        type: MovementType.income,
        amount: amount,
        date: date,
        serviceId: serviceId,
        clientId: clientId,
        employee: employee,
        createdAt: DateTime.now(),
      );

  Movement expense({
    required double amount,
    required DateTime date,
    int? categoryId,
  }) =>
      Movement(
        type: MovementType.expense,
        amount: amount,
        date: date,
        expenseCategoryId: categoryId,
        createdAt: DateTime.now(),
      );

  test('first run seeds default services and expense categories', () async {
    final services = await catalogs.services();
    final categories = await catalogs.expenseCategories();

    expect(services, hasLength(7));
    expect(services.map((s) => s.name), containsAll(['Corte', 'Tinte']));
    expect(categories, hasLength(9));
    expect(categories.map((c) => c.name), containsAll(['Renta', 'Sueldos']));
  });

  test('totals net equals income minus expenses for the day', () async {
    final today = DateTime(2026, 9, 16, 10, 30);
    await movements.insert(income(amount: 100, date: today, serviceId: 1));
    await movements.insert(income(amount: 50, date: today, serviceId: 2));
    await movements.insert(expense(amount: 40, date: today, categoryId: 1));

    final totals = await finance.totalsForDay(today);

    expect(totals.income, 150);
    expect(totals.expense, 40);
    expect(totals.net, 110);
  });

  test('query filters by type, range and client', () async {
    final day = DateTime(2026, 9, 16, 12);
    final clientId = await clients.insert(
      Client(name: 'María', createdAt: DateTime.now()),
    );
    await movements.insert(
      income(amount: 80, date: day, serviceId: 1, clientId: clientId),
    );
    await movements.insert(expense(amount: 30, date: day, categoryId: 2));
    await movements.insert(
      income(
        amount: 999,
        date: day.add(const Duration(days: 40)),
        serviceId: 1,
      ),
    );

    final onlyIncome = await movements.query(
      filter: MovementFilter(type: MovementType.income),
    );
    expect(onlyIncome, hasLength(2));

    final inRange = await movements.query(
      filter: MovementFilter(range: DateTimeRange(start: day, end: day)),
    );
    expect(inRange, hasLength(2));

    final ofClient = await movements.query(
      filter: MovementFilter(clientId: clientId),
    );
    expect(ofClient, hasLength(1));
    expect(ofClient.single.clientName, 'María');
    expect(ofClient.single.categoryName, 'Corte');
  });

  test('expenses group by category for the pie chart', () async {
    final day = DateTime(2026, 9, 16);
    await movements.insert(expense(amount: 20, date: day, categoryId: 1));
    await movements.insert(expense(amount: 30, date: day, categoryId: 1));
    await movements.insert(expense(amount: 10, date: day, categoryId: 2));

    final slices = await finance.expensesByCategory(
      DateTimeRange(start: day, end: day),
    );

    expect(slices, hasLength(2));
    expect(slices.first.total, 50); // ordered by total desc
    expect(slices.first.name, 'Productos');
  });

  test('closing the same day twice updates instead of duplicating',
      () async {
    final day = DateTime(2026, 9, 16, 9);
    await movements.insert(income(amount: 100, date: day, serviceId: 1));

    await finance.closeDay(day);
    // Another sale after closing, then a re-close.
    await movements.insert(income(amount: 25, date: day, serviceId: 1));
    await finance.closeDay(day);

    final closes = await finance.listCloses();
    expect(closes, hasLength(1));
    expect(closes.single.totalIncome, 125);
    expect(await finance.isDayClosed(day), isTrue);
  });

  test('monthly goal upserts per month', () async {
    await finance.setGoal(const MonthlyGoal(month: '2026-09', amount: 1000));
    await finance.setGoal(const MonthlyGoal(month: '2026-09', amount: 1500));

    final goal = await finance.goalForMonth('2026-09');
    expect(goal?.amount, 1500);
    expect(await finance.goalForMonth('2026-10'), isNull);
  });

  test('trend groups movements by month, oldest first', () async {
    await movements.insert(
      income(amount: 100, date: DateTime(2026, 7, 10), serviceId: 1),
    );
    await movements.insert(
      income(amount: 200, date: DateTime(2026, 8, 10), serviceId: 1),
    );
    await movements.insert(
      expense(amount: 50, date: DateTime(2026, 8, 11), categoryId: 1),
    );

    final trend = await finance.monthlyTrend(6);

    expect(trend.map((p) => p.month), ['2026-07', '2026-08']);
    expect(trend.last.income, 200);
    expect(trend.last.expense, 50);
  });

  test('deleting a client keeps movements but clears the link', () async {
    final clientId = await clients.insert(
      Client(name: 'Ana', createdAt: DateTime.now()),
    );
    final movementId = await movements.insert(
      income(
        amount: 60,
        date: DateTime(2026, 9, 16),
        serviceId: 1,
        clientId: clientId,
      ),
    );

    await clients.delete(clientId);

    final movement = await movements.byId(movementId);
    expect(movement, isNotNull);
    expect(movement!.clientId, isNull);
    expect(movement.clientName, isNull);
  });

  test('inserting an appointment and reading it back preserves all fields',
      () async {
    final clientId = await clients.insert(
      Client(name: 'Carla', createdAt: DateTime.now()),
    );
    final createdAt = DateTime(2026, 9, 19, 8);

    final id = await appointments.insert(
      Appointment(
        clientId: clientId,
        dateTime: DateTime(2026, 9, 25, 15, 30),
        createdAt: createdAt,
      ),
    );

    final saved = await appointments.byId(id);

    expect(saved, isNotNull);
    expect(saved!.clientId, clientId);
    expect(saved.dateTime, DateTime(2026, 9, 25, 15, 30));
    expect(saved.description, isNull);
    expect(saved.notificationId, isNull);
    expect(saved.createdAt, createdAt);
    expect(saved.clientName, 'Carla');
  });

  test(
      'upcoming returns only appointments at or after the reference time, '
      'ordered chronologically', () async {
    final clientId = await clients.insert(
      Client(name: 'Diego', createdAt: DateTime.now()),
    );
    final reference = DateTime(2026, 9, 20, 9);

    final pastId = await appointments.insert(
      Appointment(
        clientId: clientId,
        dateTime: reference.subtract(const Duration(days: 1)),
        createdAt: DateTime.now(),
      ),
    );
    await appointments.insert(
      Appointment(
        clientId: clientId,
        dateTime: reference.add(const Duration(days: 5)),
        description: 'Tinte',
        createdAt: DateTime.now(),
      ),
    );
    await appointments.insert(
      Appointment(
        clientId: clientId,
        dateTime: reference,
        createdAt: DateTime.now(),
      ),
    );

    final result = await appointments.upcoming(from: reference);

    expect(result, hasLength(2));
    expect(
      result.map((a) => a.dateTime),
      [reference, reference.add(const Duration(days: 5))],
    );
    expect(result.every((a) => a.id != pastId), isTrue);
  });

  test(
      'deleting a client keeps its appointments but the client join no '
      'longer resolves', () async {
    final clientId = await clients.insert(
      Client(name: 'Luisa', createdAt: DateTime.now()),
    );
    final appointmentId = await appointments.insert(
      Appointment(
        clientId: clientId,
        dateTime: DateTime(2026, 9, 21, 10),
        createdAt: DateTime.now(),
      ),
    );

    await clients.delete(clientId);

    // Appointment.clientId is NOT NULL (an appointment always needs a
    // client, per product decision), so unlike Movement's optional
    // client_id it can't be nulled out on client deletion. ClientRepository
    // .delete only clears the link on `movements`; it never touches
    // `appointments`, and this DB never enables `PRAGMA foreign_keys`. So
    // the appointment row is kept unmodified — same "keep the record"
    // precedent as movements — just with a stale client_id and a
    // display-only clientName that degrades to null via the LEFT JOIN.
    final appointment = await appointments.byId(appointmentId);
    expect(appointment, isNotNull);
    expect(appointment!.clientId, clientId);
    expect(appointment.clientName, isNull);
  });

  test('date helpers produce lexicographic-sortable keys', () {
    final a = DateTime(2026, 1, 5, 9, 30);
    final b = DateTime(2026, 1, 5, 18, 0);
    final c = DateTime(2026, 2, 1);

    expect(
      DateHelpers.dateTimeKey(a).compareTo(DateHelpers.dateTimeKey(b)) < 0,
      isTrue,
    );
    expect(
      DateHelpers.dateTimeKey(b).compareTo(DateHelpers.dateTimeKey(c)) < 0,
      isTrue,
    );
    expect(DateHelpers.dayKey(a), '2026-01-05');
    expect(DateHelpers.monthKey(a), '2026-01');
  });
}
