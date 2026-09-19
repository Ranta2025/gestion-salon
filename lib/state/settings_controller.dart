import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/formatters.dart';
import '../../services/backup_service.dart';

/// App-wide preferences + backup orchestration.
class SettingsController extends ChangeNotifier {
  static const String _currencyKey = 'currency_symbol';

  final BackupService _backup;

  SettingsController({BackupService? backup})
      : _backup = backup ?? BackupService();

  String currencySymbol = Formatters.currencySymbol;
  bool busy = false;
  String? lastMessage;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    currencySymbol = prefs.getString(_currencyKey) ?? '\$';
    Formatters.currencySymbol = currencySymbol;
    notifyListeners();
  }

  Future<void> setCurrency(String symbol) async {
    final trimmed = symbol.trim();
    if (trimmed.isEmpty) return;
    currencySymbol = trimmed;
    Formatters.currencySymbol = trimmed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currencyKey, trimmed);
    notifyListeners();
  }

  Future<void> exportBackup() => _run(
        () async {
          await _backup.exportBackup();
          return 'Respaldo generado. Guardalo en un lugar seguro.';
        },
      );

  Future<void> importBackup() => _run(_backup.importBackup);

  Future<void> _run(Future<String> Function() action) async {
    busy = true;
    lastMessage = null;
    notifyListeners();
    try {
      lastMessage = await action();
    } on FormatException catch (e) {
      lastMessage = 'No se pudo restaurar: ${e.message}';
    } catch (e) {
      lastMessage = 'Ocurrió un error: $e';
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
