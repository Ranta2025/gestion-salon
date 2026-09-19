import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

import '../data/db/app_database.dart';

/// Local-only backup: the whole database serialized to one JSON file.
/// Export shares the file through the OS; import reads a file the user
/// picks. No server, no account, no network.
class BackupService {
  static const String format = 'gestion-salon-backup';
  static const int backupVersion = 1;

  static const List<String> _tables = [
    'clients',
    'services',
    'expense_categories',
    'movements',
    'cash_closes',
    'goals',
  ];

  Future<String> exportBackup() async {
    final db = await AppDatabase.database;
    final data = <String, Object?>{
      'format': format,
      'version': backupVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'tables': {
        for (final table in _tables) table: await db.query(table),
      },
    };

    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('.', '')
        .substring(0, 15);
    final file = File('${dir.path}/gestion_salon_backup_$stamp.json');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'Respaldo Gestión Salón',
      ),
    );
    return file.path;
  }

  /// Returns a human-readable summary on success.
  /// Throws [FormatException] on invalid files; existing data is only
  /// touched after the whole payload validates.
  Future<String> importBackup() async {
    final picked = await FilePicker.pickFile(
      dialogTitle: 'Elegí tu archivo de respaldo',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final path = picked?.path;
    if (path == null) return 'Restauración cancelada';

    final raw = await File(path).readAsString();
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('El archivo no es un respaldo válido');
    }
    if (decoded['format'] != format) {
      throw const FormatException('El archivo no pertenece a Gestión Salón');
    }
    if (decoded['version'] != backupVersion) {
      throw FormatException(
        'Versión de respaldo no soportada: ${decoded['version']}',
      );
    }
    final tables = decoded['tables'];
    if (tables is! Map<String, Object?>) {
      throw const FormatException('El respaldo no contiene datos');
    }

    // Validate every table before mutating anything.
    final parsed = <String, List<Map<String, Object?>>>{};
    for (final table in _tables) {
      final rows = tables[table];
      if (rows is! List) {
        throw FormatException('Tabla faltante o inválida: $table');
      }
      parsed[table] = rows
          .whereType<Map>()
          .map((r) => r.map((k, v) => MapEntry(k.toString(), v)))
          .toList();
    }

    final db = await AppDatabase.database;
    await db.transaction((txn) async {
      for (final table in _tables.reversed) {
        await txn.delete(table);
      }
      for (final table in _tables) {
        for (final row in parsed[table]!) {
          await txn.insert(
            table,
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });

    final counts = parsed.entries
        .map((e) => '${e.key}: ${e.value.length}')
        .join(', ');
    return 'Datos restaurados ($counts)';
  }
}
