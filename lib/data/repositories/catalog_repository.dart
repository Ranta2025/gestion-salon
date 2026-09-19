import '../db/app_database.dart';
import '../models/models.dart';

/// Configurable catalogs: services (income categories with optional saved
/// price) and expense categories.
class CatalogRepository {
  Future<List<ServiceItem>> services({bool activeOnly = true}) async {
    final db = await AppDatabase.database;
    final rows = await db.query(
      'services',
      where: activeOnly ? 'active = 1' : null,
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map(ServiceItem.fromMap).toList();
  }

  Future<int> upsertService(ServiceItem service) async {
    final db = await AppDatabase.database;
    final map = service.toMap();
    if (service.id == null) {
      map.remove('id');
      return db.insert('services', map);
    }
    await db.update('services', map, where: 'id = ?', whereArgs: [service.id]);
    return service.id!;
  }

  Future<void> setServiceActive(int id, bool active) async {
    final db = await AppDatabase.database;
    await db.update(
      'services',
      {'active': active ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteService(int id) async {
    final db = await AppDatabase.database;
    await db.delete('services', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<ExpenseCategory>> expenseCategories({
    bool activeOnly = true,
  }) async {
    final db = await AppDatabase.database;
    final rows = await db.query(
      'expense_categories',
      where: activeOnly ? 'active = 1' : null,
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map(ExpenseCategory.fromMap).toList();
  }

  Future<int> upsertExpenseCategory(ExpenseCategory category) async {
    final db = await AppDatabase.database;
    final map = category.toMap();
    if (category.id == null) {
      map.remove('id');
      return db.insert('expense_categories', map);
    }
    await db.update(
      'expense_categories',
      map,
      where: 'id = ?',
      whereArgs: [category.id],
    );
    return category.id!;
  }

  Future<void> deleteExpenseCategory(int id) async {
    final db = await AppDatabase.database;
    await db.delete('expense_categories', where: 'id = ?', whereArgs: [id]);
  }
}
