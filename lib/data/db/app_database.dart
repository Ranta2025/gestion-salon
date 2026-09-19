import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// SQLite access point. Single database, versioned schema, seeded catalogs.
///
/// Everything lives on-device: no network, no sync, no external storage
/// required for normal operation.
class AppDatabase {
  AppDatabase._();

  static const String _dbName = 'gestion_salon.db';
  static const int _dbVersion = 2;

  static Database? _instance;

  static Future<Database> get database async {
    final existing = _instance;
    if (existing != null) return existing;
    _instance = await _open();
    return _instance!;
  }

  /// Visible for testing: lets unit tests inject an in-memory database.
  static void debugSetDatabase(Database db) => _instance = db;

  /// Visible for testing: exposes the schema creator so tests can build
  /// an in-memory database with the real structure and seed data.
  static Future<void> createSchemaForTest(Database db) =>
      _onCreate(db, _dbVersion);

  static Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Existing installs created before the `appointments` table (version 1)
  /// need it added explicitly — `onCreate` only runs for brand-new databases.
  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE appointments(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          client_id INTEGER NOT NULL REFERENCES clients(id),
          date_time TEXT NOT NULL,
          description TEXT,
          notification_id INTEGER,
          created_at TEXT NOT NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX idx_appointments_date_time ON appointments(date_time)',
      );
    }
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE clients(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE services(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        price REAL NOT NULL DEFAULT 0,
        active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE expense_categories(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE movements(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL CHECK(type IN ('income','expense')),
        amount REAL NOT NULL CHECK(amount > 0),
        date TEXT NOT NULL,
        service_id INTEGER REFERENCES services(id),
        expense_category_id INTEGER REFERENCES expense_categories(id),
        client_id INTEGER REFERENCES clients(id),
        employee TEXT,
        supplier TEXT,
        payment_method TEXT NOT NULL DEFAULT 'efectivo',
        note TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_movements_date ON movements(date)',
    );
    await db.execute(
      'CREATE INDEX idx_movements_type ON movements(type)',
    );
    await db.execute(
      'CREATE INDEX idx_movements_client ON movements(client_id)',
    );

    await db.execute('''
      CREATE TABLE appointments(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_id INTEGER NOT NULL REFERENCES clients(id),
        date_time TEXT NOT NULL,
        description TEXT,
        notification_id INTEGER,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_appointments_date_time ON appointments(date_time)',
    );

    await db.execute('''
      CREATE TABLE cash_closes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL UNIQUE,
        total_income REAL NOT NULL,
        total_expense REAL NOT NULL,
        net REAL NOT NULL,
        closed_at TEXT NOT NULL,
        note TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE goals(
        month TEXT PRIMARY KEY,
        amount REAL NOT NULL
      )
    ''');

    await _seed(db);
  }

  /// Default catalogs so the app is useful from the first launch.
  static Future<void> _seed(Database db) async {
    const services = [
      'Corte',
      'Tinte',
      'Peinado',
      'Tratamiento',
      'Uñas',
      'Productos',
      'Otros',
    ];
    for (final name in services) {
      await db.insert('services', {'name': name, 'price': 0.0});
    }

    const categories = [
      'Productos',
      'Renta',
      'Luz',
      'Agua',
      'Internet',
      'Sueldos',
      'Mantenimiento',
      'Publicidad',
      'Otros',
    ];
    for (final name in categories) {
      await db.insert('expense_categories', {'name': name});
    }
  }
}
