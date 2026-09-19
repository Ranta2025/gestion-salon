import 'package:flutter/foundation.dart';

import '../../data/models/models.dart';
import '../../data/repositories/movement_repository.dart';

class MovementsController extends ChangeNotifier {
  final MovementRepository _repository;

  MovementsController({MovementRepository? repository})
      : _repository = repository ?? MovementRepository();

  MovementFilter filter = const MovementFilter();
  List<Movement> movements = const [];
  List<String> employees = const [];
  bool loading = true;

  Future<void> refresh() async {
    loading = true;
    notifyListeners();
    final results = await Future.wait([
      _repository.query(filter: filter, limit: 500),
      _repository.distinctEmployees(),
    ]);
    movements = results[0] as List<Movement>;
    employees = results[1] as List<String>;
    loading = false;
    notifyListeners();
  }

  Future<void> setFilter(MovementFilter next) async {
    filter = next;
    await refresh();
  }

  Future<void> loadEmployees() async {
    employees = await _repository.distinctEmployees();
    notifyListeners();
  }

  Future<int> add(Movement movement) async {
    final id = await _repository.insert(movement);
    await refresh();
    return id;
  }

  Future<void> update(Movement movement) async {
    await _repository.update(movement);
    await refresh();
  }

  Future<void> delete(int id) async {
    await _repository.delete(id);
    await refresh();
  }
}
