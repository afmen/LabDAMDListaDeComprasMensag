import 'package:flutter/foundation.dart';
import '../models/shopping_list.dart';
import '../models/shopping_item.dart'; // Importação normal, sem conflitos
import '../services/database_service.dart';
import '../services/sync_service.dart';
import '../services/connectivity_service.dart';

class ListProvider with ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;
  final SyncService _syncService = SyncService();
  final ConnectivityService _connectivity = ConnectivityService.instance;

  List<ShoppingList> _lists = [];
  List<ShoppingItem> _currentItems = [];

  bool get isOnline => _connectivity.isOnline;
  List<ShoppingList> get lists => _lists;
  List<ShoppingItem> get currentItems => _currentItems;

  void initialize() {
    loadLists();
    
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

  // --- Operações de Lista ---

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

  // --- Operações de Itens ---
  
  Future<void> loadItems(String listId) async {
    _currentItems = await _db.getItemsByList(listId);
    notifyListeners();
  }

  Future<void> addItem(String listId, String name, double qty) async {
    final item = ShoppingItem(listId: listId, name: name, quantity: qty);
    
    _currentItems.add(item); 
    notifyListeners();

    await _syncService.addItem(item);
    await loadItems(listId);
  }

  Future<void> toggleItem(ShoppingItem item) async {
    final newItem = item.copyWith(purchased: !item.purchased);
    
    final index = _currentItems.indexWhere((i) => i.id == item.id);
    if (index != -1) {
      _currentItems[index] = newItem;
      notifyListeners();
    }

    await _syncService.updateItem(newItem);
  }

  Future<void> manualSync() async {
    await _syncService.sync();
    await loadLists();
  }
}