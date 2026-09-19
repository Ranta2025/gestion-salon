import '../db/app_database.dart';
import '../models/models.dart';
import 'movement_repository.dart';

class ClientRepository {
  final MovementRepository _movements = MovementRepository();

  Future<int> insert(Client client) async {
    final db = await AppDatabase.database;
    final map = client.toMap()..remove('id');
    return db.insert('clients', map);
  }

  Future<void> update(Client client) async {
    final db = await AppDatabase.database;
    await db.update(
      'clients',
      client.toMap(),
      where: 'id = ?',
      whereArgs: [client.id],
    );
  }

  Future<void> delete(int id) async {
    final db = await AppDatabase.database;
    // Movements keep their client_id; joins degrade to null gracefully,
    // but we clear the link explicitly to avoid phantom references.
    await db.update(
      'movements',
      {'client_id': null},
      where: 'client_id = ?',
      whereArgs: [id],
    );
    await db.delete('clients', where: 'id = ?', whereArgs: [id]);
  }

  Future<Client?> byId(int id) async {
    final db = await AppDatabase.database;
    final rows =
        await db.query('clients', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Client.fromMap(rows.first);
  }

  Future<List<Client>> search(String query) async {
    final db = await AppDatabase.database;
    final rows = await db.query(
      'clients',
      where: query.isEmpty ? null : 'name LIKE ?',
      whereArgs: query.isEmpty ? null : ['%$query%'],
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map(Client.fromMap).toList();
  }

  /// Visit history: all income movements linked to this client.
  Future<List<Movement>> history(int clientId) =>
      _movements.query(
        filter: MovementFilter(
          type: MovementType.income,
          clientId: clientId,
        ),
      );

  Future<double> totalSpent(int clientId) async {
    final db = await AppDatabase.database;
    final rows = await db.rawQuery(
      "SELECT COALESCE(SUM(amount), 0) AS total FROM movements "
      "WHERE type = 'income' AND client_id = ?",
      [clientId],
    );
    return (rows.first['total'] as num).toDouble();
  }
}
