import '../../core/utils/date_helpers.dart';
import '../db/app_database.dart';
import '../models/models.dart';

/// Filters supported by the reports and movements screens.
class MovementFilter {
  final DateTimeRange? range;
  final MovementType? type;
  final int? serviceId;
  final int? expenseCategoryId;
  final int? clientId;
  final String? employee;

  const MovementFilter({
    this.range,
    this.type,
    this.serviceId,
    this.expenseCategoryId,
    this.clientId,
    this.employee,
  });
}

class MovementRepository {
  static const String _select = '''
    SELECT m.*,
      CASE WHEN m.type = 'income' THEN s.name ELSE ec.name END AS category_name,
      c.name AS client_name
    FROM movements m
    LEFT JOIN services s ON m.service_id = s.id
    LEFT JOIN expense_categories ec ON m.expense_category_id = ec.id
    LEFT JOIN clients c ON m.client_id = c.id
  ''';

  Future<int> insert(Movement movement) async {
    final db = await AppDatabase.database;
    final map = movement.toMap()..remove('id');
    return db.insert('movements', map);
  }

  Future<void> update(Movement movement) async {
    final db = await AppDatabase.database;
    await db.update(
      'movements',
      movement.toMap()..remove('created_at'),
      where: 'id = ?',
      whereArgs: [movement.id],
    );
  }

  Future<void> delete(int id) async {
    final db = await AppDatabase.database;
    await db.delete('movements', where: 'id = ?', whereArgs: [id]);
  }

  Future<Movement?> byId(int id) async {
    final db = await AppDatabase.database;
    final rows = await db.rawQuery('$_select WHERE m.id = ?', [id]);
    if (rows.isEmpty) return null;
    return Movement.fromMap(rows.first);
  }

  Future<List<Movement>> query({
    MovementFilter filter = const MovementFilter(),
    int? limit,
  }) async {
    final db = await AppDatabase.database;
    final where = <String>[];
    final args = <Object?>[];

    if (filter.range != null) {
      where.add('m.date >= ? AND m.date <= ?');
      args.add('${DateHelpers.dayKey(filter.range!.start)} 00:00:00');
      args.add('${DateHelpers.dayKey(filter.range!.end)} 23:59:59');
    }
    if (filter.type != null) {
      where.add('m.type = ?');
      args.add(filter.type!.dbValue);
    }
    if (filter.serviceId != null) {
      where.add('m.service_id = ?');
      args.add(filter.serviceId);
    }
    if (filter.expenseCategoryId != null) {
      where.add('m.expense_category_id = ?');
      args.add(filter.expenseCategoryId);
    }
    if (filter.clientId != null) {
      where.add('m.client_id = ?');
      args.add(filter.clientId);
    }
    if (filter.employee != null && filter.employee!.isNotEmpty) {
      where.add('m.employee = ?');
      args.add(filter.employee);
    }

    final sql = StringBuffer(_select);
    if (where.isNotEmpty) sql.write(' WHERE ${where.join(' AND ')}');
    sql.write(' ORDER BY m.date DESC, m.id DESC');
    if (limit != null) sql.write(' LIMIT $limit');

    final rows = await db.rawQuery(sql.toString(), args);
    return rows.map(Movement.fromMap).toList();
  }

  Future<List<Movement>> latest(int count) =>
      query(limit: count);

  /// Distinct employee names ever recorded — feeds form autocomplete
  /// and the reports employee filter.
  Future<List<String>> distinctEmployees() async {
    final db = await AppDatabase.database;
    final rows = await db.rawQuery(
      "SELECT DISTINCT employee FROM movements "
      "WHERE employee IS NOT NULL AND employee != '' ORDER BY employee",
    );
    return rows.map((r) => r['employee'] as String).toList();
  }
}
