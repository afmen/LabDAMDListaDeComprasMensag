import 'dart:async';
import 'dart:convert';
import '../models/shopping_list.dart';
import '../models/shopping_item.dart';
import '../models/sync_operation.dart';
import 'database_service.dart';
import 'api_service.dart';
import 'connectivity_service.dart';

class SyncService {
  final DatabaseService _db = DatabaseService.instance;
  final ApiService _api = ApiService();
  final ConnectivityService _connectivity = ConnectivityService.instance;
  
  bool _isSyncing = false;
  Timer? _autoSyncTimer;

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

  // --- Operações de Itens ---
  Future<void> addItem(ShoppingItem item) async {
    await _db.upsertItem(item.copyWith(syncStatus: SyncStatus.pending));
    final data = item.toJson();
    data['parent_list_id'] = item.listId; 
    await _db.addToSyncQueue(SyncOperation(type: OperationType.create, taskId: "ITEM#${item.id}", data: data));
    if (_connectivity.isOnline) sync();
  }

  Future<void> updateItem(ShoppingItem item) async {
    await _db.upsertItem(item.copyWith(syncStatus: SyncStatus.pending));
    final data = item.toJson();
    data['parent_list_id'] = item.listId;
    await _db.addToSyncQueue(SyncOperation(type: OperationType.update, taskId: "ITEM#${item.id}", data: data));
    if (_connectivity.isOnline) sync();
  }

  Future<void> deleteItem(String itemId, String listId) async {
    await _db.deleteItem(itemId);
    await _db.addToSyncQueue(SyncOperation(type: OperationType.delete, taskId: "ITEM#$itemId", data: {'parent_list_id': listId}));
    if (_connectivity.isOnline) sync();
  }

  // --- Engine de Sincronização ---
  Future<void> sync() async {
    if (_isSyncing || !_connectivity.isOnline) return;
    _isSyncing = true;
    print('🔄 Sync Iniciado...');

    try {
      // 1. PUSH
      final pendingOps = await _db.getPendingSyncOperations();
      for (final op in pendingOps) {
        try {
          final isItem = op.taskId.startsWith("ITEM#");
          final realId = isItem ? op.taskId.replaceAll("ITEM#", "") : op.taskId;

          if (isItem) {
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
            // LISTAS
            if (op.type == OperationType.create) {
              final list = await _db.getList(op.taskId);
              if (list != null) {
                final serverList = await _api.createList(list);
                
                // CORREÇÃO DE DUPLICAÇÃO:
                // Se o ID do servidor for diferente do local, migra os dados
                if (serverList.id != list.id) {
                  print('🔄 Migrando ID da lista: ${list.id} -> ${serverList.id}');
                  await _db.migrateListData(list.id, serverList);
                } else {
                  await _db.upsertList(serverList.copyWith(syncStatus: SyncStatus.synced));
                }
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
      
      // 2. PULL
      final serverLists = await _api.getLists();
      for (final sList in serverLists) {
        final local = await _db.getList(sList.id);
        if (local == null || local.syncStatus == SyncStatus.synced) {
          await _db.upsertList(sList.copyWith(syncStatus: SyncStatus.synced));
        } else {
           final localTime = local.localUpdatedAt ?? local.updatedAt;
           final serverTime = sList.updatedAt;
           if (localTime.isAfter(serverTime)) {
             await _api.updateList(local);
             await _db.upsertList(local.copyWith(syncStatus: SyncStatus.synced));
           } else {
             await _db.upsertList(sList.copyWith(syncStatus: SyncStatus.synced));
           }
        }
      }
      await _db.setMetadata('lastSyncTimestamp', DateTime.now().millisecondsSinceEpoch.toString());

    } finally {
      _isSyncing = false;
      print('✅ Sync Finalizado');
    }
  }

  // --- AUTO SYNC ---
  void startAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_connectivity.isOnline && !_isSyncing) {
        print('⏰ Auto-Sync periódico disparado');
        sync();
      }
    });
  }

  Future<SyncStats> getStats() async {
    final statsMap = await _db.getStats();
    final lastSyncStr = await _db.getMetadata('lastSyncTimestamp');
    final lastSync = lastSyncStr != null ? DateTime.fromMillisecondsSinceEpoch(int.parse(lastSyncStr)) : null;

    return SyncStats(
      totalLists: statsMap['totalLists'] ?? 0,
      unsyncedLists: statsMap['unsyncedLists'] ?? 0,
      queuedOperations: statsMap['queuedOperations'] ?? 0,
      lastSync: lastSync,
      isOnline: _connectivity.isOnline,
      isSyncing: _isSyncing,
    );
  }
}

class SyncStats {
  final int totalLists;
  final int unsyncedLists;
  final int queuedOperations;
  final DateTime? lastSync;
  final bool isOnline;
  final bool isSyncing;

  SyncStats({
    required this.totalLists,
    required this.unsyncedLists,
    required this.queuedOperations,
    this.lastSync,
    required this.isOnline,
    required this.isSyncing,
  });
}