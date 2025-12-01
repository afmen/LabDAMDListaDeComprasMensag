import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/shopping_list.dart';
import '../models/shopping_item.dart';
import '../models/sync_operation.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('shopping_offline_v4.db'); // Incrementando versão para forçar recriação limpa
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE shopping_lists (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        status TEXT NOT NULL,
        userId TEXT NOT NULL,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL,
        syncStatus TEXT NOT NULL,
        localUpdatedAt INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE shopping_items (
        id TEXT PRIMARY KEY,
        listId TEXT NOT NULL,
        name TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit TEXT NOT NULL,
        estimatedPrice REAL NOT NULL,
        purchased INTEGER NOT NULL DEFAULT 0,
        notes TEXT,
        addedAt INTEGER NOT NULL,
        syncStatus TEXT NOT NULL,
        FOREIGN KEY (listId) REFERENCES shopping_lists (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE sync_queue (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        taskId TEXT NOT NULL,
        data TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        retries INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL,
        error TEXT
      )
    ''');

    await db.execute('CREATE TABLE metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
  }

  // --- Operações de Listas ---
  Future<ShoppingList> upsertList(ShoppingList list) async {
    final db = await database;
    await db.insert('shopping_lists', list.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    return list;
  }

  Future<ShoppingList?> getList(String id) async {
    final db = await database;
    final maps = await db.query('shopping_lists', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return ShoppingList.fromMap(maps.first);
  }

  Future<List<ShoppingList>> getAllLists() async {
    final db = await database;
    final maps = await db.query('shopping_lists', orderBy: 'updatedAt DESC');
    return maps.map((map) => ShoppingList.fromMap(map)).toList();
  }

  Future<void> deleteList(String id) async {
    final db = await database;
    await db.delete('shopping_items', where: 'listId = ?', whereArgs: [id]);
    await db.delete('shopping_lists', where: 'id = ?', whereArgs: [id]);
  }

  // --- MIGRAÇÃO DE ID (Correção da Duplicação) ---
  // Troca o ID local temporário pelo ID real do servidor
  Future<void> migrateListData(String oldLocalId, ShoppingList serverList) async {
    final db = await database;
    await db.transaction((txn) async {
      // 1. Inserir a lista oficial (vinda do servidor)
      await txn.insert(
        'shopping_lists', 
        serverList.copyWith(syncStatus: SyncStatus.synced).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace
      );

      // 2. Mover todos os itens da lista antiga para a nova
      await txn.update(
        'shopping_items', 
        {'listId': serverList.id}, 
        where: 'listId = ?', 
        whereArgs: [oldLocalId]
      );

      // 3. Apagar a lista antiga (local)
      await txn.delete('shopping_lists', where: 'id = ?', whereArgs: [oldLocalId]);
    });
  }

  // --- Operações de Itens ---
  Future<ShoppingItem> upsertItem(ShoppingItem item) async {
    final db = await database;
    await db.insert('shopping_items', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    return item;
  }

  Future<List<ShoppingItem>> getItemsByList(String listId) async {
    final db = await database;
    final maps = await db.query('shopping_items', where: 'listId = ?', whereArgs: [listId], orderBy: 'addedAt DESC');
    return maps.map((map) => ShoppingItem.fromMap(map)).toList();
  }

  Future<ShoppingItem?> getItem(String id) async {
    final db = await database;
    final maps = await db.query('shopping_items', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return ShoppingItem.fromMap(maps.first);
  }

  Future<void> deleteItem(String id) async {
    final db = await database;
    await db.delete('shopping_items', where: 'id = ?', whereArgs: [id]);
  }

  // --- Fila e Metadata ---
  Future<void> addToSyncQueue(SyncOperation operation) async {
    final db = await database;
    await db.insert('sync_queue', operation.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<SyncOperation>> getPendingSyncOperations() async {
    final db = await database;
    final maps = await db.query('sync_queue', where: 'status = ?', whereArgs: [SyncOperationStatus.pending.toString()], orderBy: 'timestamp ASC');
    return maps.map((map) => SyncOperation.fromMap(map)).toList();
  }

  Future<void> removeSyncOperation(String id) async {
    final db = await database;
    await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }
  
  Future<void> setMetadata(String key, String value) async {
    final db = await database;
    await db.insert('metadata', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getMetadata(String key) async {
    final db = await database;
    final maps = await db.query('metadata', where: 'key = ?', whereArgs: [key]);
    if (maps.isEmpty) return null;
    return maps.first['value'] as String;
  }

  Future<Map<String, int>> getStats() async {
    final db = await database;
    final totalLists = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM shopping_lists')) ?? 0;
    final unsyncedLists = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM shopping_lists WHERE syncStatus = ?', [SyncStatus.pending.toString()])) ?? 0;
    final queuedOps = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM sync_queue WHERE status = ?', [SyncOperationStatus.pending.toString()])) ?? 0;

    return {
      'totalLists': totalLists,
      'unsyncedLists': unsyncedLists,
      'queuedOperations': queuedOps,
    };
  }
}