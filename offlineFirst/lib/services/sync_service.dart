import 'dart:async';
import '../models/shopping_list.dart';
import '../models/sync_operation.dart';
import 'database_service.dart';
import 'api_service.dart';
import 'connectivity_service.dart';

class SyncService {
  final DatabaseService _db = DatabaseService.instance;
  final ApiService _api = ApiService();
  final ConnectivityService _connectivity = ConnectivityService.instance;
  
  bool _isSyncing = false;

  // --- Operações Locais (Interceptam a UI) ---

  Future<void> createList(ShoppingList list) async {
    // 1. Salvar localmente (Pendente)
    await _db.upsertList(list.copyWith(
      syncStatus: SyncStatus.pending,
      localUpdatedAt: DateTime.now(),
    ));

    // 2. Fila
    await _db.addToSyncQueue(SyncOperation(
      type: OperationType.create,
      taskId: list.id, // Usamos taskId para guardar o ID da lista
      data: list.toJson(),
    ));

    // 3. Tentar Sync
    if (_connectivity.isOnline) sync();
  }

  Future<void> updateList(ShoppingList list) async {
    await _db.upsertList(list.copyWith(
      syncStatus: SyncStatus.pending,
      localUpdatedAt: DateTime.now(),
    ));

    await _db.addToSyncQueue(SyncOperation(
      type: OperationType.update,
      taskId: list.id,
      data: list.toJson(),
    ));

    if (_connectivity.isOnline) sync();
  }

  Future<void> deleteList(String id) async {
    await _db.deleteList(id); // Soft delete seria melhor, mas hard delete para demo
    
    await _db.addToSyncQueue(SyncOperation(
      type: OperationType.delete,
      taskId: id,
      data: {},
    ));

    if (_connectivity.isOnline) sync();
  }

  // --- Engine de Sincronização ---

  Future<void> sync() async {
    if (_isSyncing || !_connectivity.isOnline) return;
    _isSyncing = true;
    print('🔄 Sync Iniciado...');

    try {
      // 1. Push (Enviar pendências)
      final pendingOps = await _db.getPendingSyncOperations();
      for (final op in pendingOps) {
        try {
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
          await _db.removeSyncOperation(op.id);
        } catch (e) {
          print('❌ Erro ao enviar op ${op.id}: $e');
        }
      }

      // 2. Pull (Buscar novidades e resolver conflitos LWW)
      try {
        final serverLists = await _api.getLists();
        for (final serverList in serverLists) {
          final localList = await _db.getList(serverList.id);

          if (localList == null) {
            // Novo no servidor
            await _db.upsertList(serverList.copyWith(syncStatus: SyncStatus.synced));
          } else if (localList.syncStatus == SyncStatus.synced) {
            // Atualização limpa
            await _db.upsertList(serverList.copyWith(syncStatus: SyncStatus.synced));
          } else {
            // CONFLITO LWW
            final localTime = localList.localUpdatedAt ?? localList.updatedAt;
            final serverTime = serverList.updatedAt;

            if (localTime.isAfter(serverTime)) {
              print('🏆 Conflito: Local venceu (${localList.name})');
              // Mantém local, força push no próximo ciclo
              await _api.updateList(localList); // Push forçado
              await _db.upsertList(localList.copyWith(syncStatus: SyncStatus.synced));
            } else {
              print('🏆 Conflito: Servidor venceu (${serverList.name})');
              await _db.upsertList(serverList.copyWith(syncStatus: SyncStatus.synced));
            }
          }
        }
      } catch (e) {
        print('❌ Erro no Pull: $e');
      }

    } finally {
      _isSyncing = false;
      print('✅ Sync Finalizado');
    }
  }
}