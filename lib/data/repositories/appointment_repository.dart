import 'package:sqflite/sqflite.dart';

import '../../core/utils/date_helpers.dart';
import '../db/app_database.dart';
import '../models/models.dart';

class AppointmentRepository {
  static const String _select = '''
    SELECT a.*, c.name AS client_name
    FROM appointments a
    LEFT JOIN clients c ON a.client_id = c.id
  ''';

  Future<int> insert(Appointment appointment, {DatabaseExecutor? executor}) async {
    final db = executor ?? await AppDatabase.database;
    final map = appointment.toMap()..remove('id');
    return db.insert('appointments', map);
  }

  /// [executor] lets a caller run this update inside an existing
  /// transaction (e.g. `AppointmentsController.complete()` pairs this with
  /// a `Movement` insert so both writes commit or roll back together).
  Future<void> update(Appointment appointment, {DatabaseExecutor? executor}) async {
    final db = executor ?? await AppDatabase.database;
    await db.update(
      'appointments',
      appointment.toMap()..remove('created_at'),
      where: 'id = ?',
      whereArgs: [appointment.id],
    );
  }

  Future<void> delete(int id) async {
    final db = await AppDatabase.database;
    await db.delete('appointments', where: 'id = ?', whereArgs: [id]);
  }

  Future<Appointment?> byId(int id) async {
    final db = await AppDatabase.database;
    final rows = await db.rawQuery('$_select WHERE a.id = ?', [id]);
    if (rows.isEmpty) return null;
    return Appointment.fromMap(rows.first);
  }

  /// Scheduled appointments at or after [from] (default: now), ordered
  /// chronologically ascending — feeds the appointments list/reminder
  /// enumeration. A cancelled or completed appointment is excluded even if
  /// its date is still in the future.
  Future<List<Appointment>> upcoming({DateTime? from}) async {
    final db = await AppDatabase.database;
    final reference = from ?? DateTime.now();
    final rows = await db.rawQuery(
      "$_select WHERE a.date_time >= ? AND a.status = 'scheduled' "
      'ORDER BY a.date_time ASC',
      [DateHelpers.dateTimeKey(reference)],
    );
    return rows.map(Appointment.fromMap).toList();
  }

  /// Every appointment regardless of status or date, newest first — feeds
  /// the full history view.
  Future<List<Appointment>> all() async {
    final db = await AppDatabase.database;
    final rows = await db.rawQuery('$_select ORDER BY a.date_time DESC');
    return rows.map(Appointment.fromMap).toList();
  }
}
