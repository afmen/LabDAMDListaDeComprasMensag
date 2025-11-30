import 'dart:async';
import 'dart:convert';
import '../models/shopping_list.dart';
import '../models/shopping_item.dart';
import '../models/sync_operation.dart';
import 'database_service.dart';
import 'api_service.dart';
import 'connectivity_service.dart';

// Estendemos os tipos de operação manualmente aqui pois o enum original pode não ter sido atualizado
// Usaremos strings no campo 'type' do DB para flexibilidade
class SyncService {
  final DatabaseService _db = DatabaseService.instance;
  final ApiService _api = ApiService();
  final ConnectivityService _connectivity = ConnectivityService.instance;
  
  bool _isSyncing = false;

  // --- Operações de Listas ---
  Future<void> createList(ShoppingList list) async {
    await _db.upsertList(list.copyWith(syncStatus: SyncStatus.pending, localUpdatedAt: DateTime.now()));
    await _db.addToSyncQueue(SyncOperation(type: OperationType.create, taskId: list.id, data: list.toJson()));
    if (_connectivity.isOnline) sync();
  }

  Future<void> updateList(ShoppingList list) async {
    await _db.upsertList(list.copyWith(syncStatus: SyncStatus.pending, localUpdatedAt: DateTime.now()));
    await _db.addToSyncQueue(SyncOperation(type: OperationType.update, taskId: list.id, data: list.toJson()));
    if (_connectivity.isOnline) sync();
  }

  Future<void> deleteList(String id) async {
    await _db.deleteList(id);
    await _db.addToSyncQueue(SyncOperation(type: OperationType.delete, taskId: id, data: {}));
    if (_connectivity.isOnline) sync();
  }

  // --- NOVAS: Operações de Itens ---
  
  Future<void> addItem(ShoppingItem item) async {
    // 1. Salvar localmente
    await _db.upsertItem(item.copyWith(syncStatus: SyncStatus.pending));
    
    // 2. Fila (Usamos type customizado se o enum não permitir, ou adaptamos o enum)
    // Aqui vou serializar o ID da lista junto no data
    final data = item.toJson();
    data['parent_list_id'] = item.listId; 

    await _db.addToSyncQueue(SyncOperation(
      type: OperationType.create, // Reutilizando create, mas o contexto será item
      taskId: "ITEM#${item.id}", // Prefixo para distinguir
      data: data,
    ));

    // 3. Trigger Automático
    if (_connectivity.isOnline) sync();
  }

  Future<void> updateItem(ShoppingItem item) async {
    await _db.upsertItem(item.copyWith(syncStatus: SyncStatus.pending));
    
    final data = item.toJson();
    data['parent_list_id'] = item.listId;

    await _db.addToSyncQueue(SyncOperation(
      type: OperationType.update,
      taskId: "ITEM#${item.id}",
      data: data,
    ));

    if (_connectivity.isOnline) sync();
  }

  Future<void> deleteItem(String itemId, String listId) async {
    await _db.deleteItem(itemId);
    
    await _db.addToSyncQueue(SyncOperation(
      type: OperationType.delete,
      taskId: "ITEM#$itemId",
      data: {'parent_list_id': listId},
    ));

    if (_connectivity.isOnline) sync();
  }

  // --- Engine de Sincronização ---

  Future<void> sync() async {
    if (_isSyncing || !_connectivity.isOnline) return;
    _isSyncing = true;
    print('🔄 Sync Iniciado...');

    try {
      final pendingOps = await _db.getPendingSyncOperations();
      for (final op in pendingOps) {
        try {
          // Detectar se é Item ou Lista baseado no ID
          final isItem = op.taskId.startsWith("ITEM#");
          final realId = isItem ? op.taskId.replaceAll("ITEM#", "") : op.taskId;

          if (isItem) {
            // --- Processar ITEM ---
            final listId = op.data['parent_list_id'];
            
            if (op.type == OperationType.create) {
              final item = await _db.getItem(realId);
              if (item != null) {
                await _api.addItem(listId, item);
                await _db.upsertItem(item.copyWith(syncStatus: SyncStatus.synced));
              }
            } else if (op.type == OperationType.update) {
              final item = await _db.getItem(realId);
              if (item != null) {
                await _api.updateItem(listId, item);
                await _db.upsertItem(item.copyWith(syncStatus: SyncStatus.synced));
              }
            } else if (op.type == OperationType.delete) {
              await _api.deleteItem(listId, realId);
            }

          } else {
            // --- Processar LISTA (Lógica existente) ---
            if (op.type == OperationType.create) {
              final list = await _db.getList(op.taskId);
              if (list != null) {
                final serverList = await _api.createList(list);
                await _db.upsertList(serverList.copyWith(syncStatus: SyncStatus.synced));
              }
            } else if (op.type == OperationType.update) {
              final list = await _db.getList(op.taskId);
              if (list != null) {
                final serverList = await _api.updateList(list);
                await _db.upsertList(serverList.copyWith(syncStatus: SyncStatus.synced));
              }
            } else if (op.type == OperationType.delete) {
              await _api.deleteList(op.taskId);
            }
          }
          await _db.removeSyncOperation(op.id);
        } catch (e) {
          print('❌ Erro op ${op.id}: $e');
        }
      }
      
      // Pull de Listas (simplificado para demo)
      final serverLists = await _api.getLists();
      for (final sList in serverLists) {
        final local = await _db.getList(sList.id);
        if (local == null || local.syncStatus == SyncStatus.synced) {
          await _db.upsertList(sList.copyWith(syncStatus: SyncStatus.synced));
        }
      }

    } finally {
      _isSyncing = false;
      print('✅ Sync Finalizado');
    }
  }
}