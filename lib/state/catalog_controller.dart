import 'package:flutter/foundation.dart';

import '../../data/models/models.dart';
import '../../data/repositories/catalog_repository.dart';

class CatalogController extends ChangeNotifier {
  final CatalogRepository _repository;

  CatalogController({CatalogRepository? repository})
      : _repository = repository ?? CatalogRepository();

  List<ServiceItem> services = const [];
  List<ExpenseCategory> expenseCategories = const [];
  bool loading = true;

  Future<void> refresh() async {
    loading = true;
    notifyListeners();
    services = await _repository.services(activeOnly: false);
    expenseCategories =
        await _repository.expenseCategories(activeOnly: false);
    loading = false;
    notifyListeners();
  }

  Future<void> saveService(ServiceItem item) async {
    await _repository.upsertService(item);
    await refresh();
  }

  Future<void> toggleService(ServiceItem item) async {
    await _repository.setServiceActive(item.id!, !item.active);
    await refresh();
  }

  Future<void> deleteService(int id) async {
    await _repository.deleteService(id);
    await refresh();
  }

  Future<void> saveExpenseCategory(ExpenseCategory category) async {
    await _repository.upsertExpenseCategory(category);
    await refresh();
  }

  Future<void> deleteExpenseCategory(int id) async {
    await _repository.deleteExpenseCategory(id);
    await refresh();
  }
}
