import 'package:flutter/foundation.dart';

import '../../data/models/models.dart';
import '../../data/repositories/client_repository.dart';

class ClientsController extends ChangeNotifier {
  final ClientRepository _repository;

  ClientsController({ClientRepository? repository})
      : _repository = repository ?? ClientRepository();

  String query = '';
  List<Client> clients = const [];
  bool loading = true;

  Future<void> refresh() async {
    loading = true;
    notifyListeners();
    clients = await _repository.search(query);
    loading = false;
    notifyListeners();
  }

  Future<void> search(String value) async {
    query = value.trim();
    await refresh();
  }

  Future<int> save(Client client) async {
    final id = await _repository.insert(client);
    await refresh();
    return id;
  }

  Future<void> update(Client client) async {
    await _repository.update(client);
    await refresh();
  }

  Future<void> delete(int id) async {
    await _repository.delete(id);
    await refresh();
  }
}
