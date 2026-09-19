import '../../core/utils/date_helpers.dart';
import '../db/app_database.dart';
import '../models/models.dart';

class AppointmentRepository {
  static const String _select = '''
    SELECT a.*, c.name AS client_name
    FROM appointments a
    LEFT JOIN clients c ON a.client_id = c.id
  ''';

  Future<int> insert(Appointment appointment) async {
    final db = await AppDatabase.database;
    final map = appointment.toMap()..remove('id');
    return db.insert('appointments', map);
  }

  Future<void> update(Appointment appointment) async {
    final db = await AppDatabase.database;
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

  /// Appointments at or after [from] (default: now), ordered chronologically
  /// ascending — feeds the appointments list/reminder enumeration.
  Future<List<Appointment>> upcoming({DateTime? from}) async {
    final db = await AppDatabase.database;
    final reference = from ?? DateTime.now();
    final rows = await db.rawQuery(
      '$_select WHERE a.date_time >= ? ORDER BY a.date_time ASC',
      [DateHelpers.dateTimeKey(reference)],
    );
    return rows.map(Appointment.fromMap).toList();
  }
}
