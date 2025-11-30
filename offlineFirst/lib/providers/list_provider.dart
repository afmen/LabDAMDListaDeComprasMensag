import 'package:flutter/foundation.dart';
import '../models/shopping_list.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import '../services/connectivity_service.dart';

class ListProvider with ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;
  final SyncService _syncService = SyncService();
  final ConnectivityService _connectivity = ConnectivityService.instance;

  List<ShoppingList> _lists = [];
  bool get isOnline => _connectivity.isOnline;

  List<ShoppingList> get lists => _lists;

  void initialize() {
    loadLists();
    
    // Escutar conectividade para auto-sync
    _connectivity.connectivityStream.listen((online) {
      notifyListeners();
      if (online) {
        _syncService.sync().then((_) => loadLists());
      }
    });
  }

  Future<void> loadLists() async {
    _lists = await _db.getAllLists();
    notifyListeners();
  }

  Future<void> addList(String name, String description) async {
    final list = ShoppingList(name: name, description: description);
    await _syncService.createList(list);
    await loadLists();
  }

  Future<void> updateList(ShoppingList list) async {
    await _syncService.updateList(list);
    await loadLists();
  }

  Future<void> deleteList(String id) async {
    await _syncService.deleteList(id);
    await loadLists();
  }

  Future<void> manualSync() async {
    await _syncService.sync();
    await loadLists();
  }
}