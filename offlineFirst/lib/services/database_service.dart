import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/task.dart';
import '../models/sync_operation.dart';

/// Serviço de gerenciamento do banco de dados SQLite local
class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('task_manager_offline.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Tabela de tarefas
    await db.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        completed INTEGER NOT NULL DEFAULT 0,
        priority TEXT NOT NULL,
        userId TEXT NOT NULL,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL,
        version INTEGER NOT NULL DEFAULT 1,
        syncStatus TEXT NOT NULL,
        localUpdatedAt INTEGER
      )
    ''');

    // Tabela de fila de sincronização
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

    // Tabela de metadados
    await db.execute('''
      CREATE TABLE metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Índices para otimização
    await db.execute('CREATE INDEX idx_tasks_userId ON tasks(userId)');
    await db.execute('CREATE INDEX idx_tasks_syncStatus ON tasks(syncStatus)');
    await db.execute('CREATE INDEX idx_sync_queue_status ON sync_queue(status)');

    print('✅ Banco de dados criado com sucesso');
  }

  // ==================== OPERAÇÕES DE TAREFAS ====================

  /// Inserir ou atualizar tarefa
  Future<Task> upsertTask(Task task) async {
    final db = await database;
    await db.insert(
      'tasks',
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return task;
  }

  /// Buscar tarefa por ID
  Future<Task?> getTask(String id) async {
    final db = await database;
    final maps = await db.query(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;
    return Task.fromMap(maps.first);
  }

  /// Buscar todas as tarefas
  Future<List<Task>> getAllTasks({String userId = 'user1'}) async {
    final db = await database;
    final maps = await db.query(
      'tasks',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'updatedAt DESC',
    );

    return maps.map((map) => Task.fromMap(map)).toList();
  }

  /// Buscar tarefas não sincronizadas
  Future<List<Task>> getUnsyncedTasks() async {
    final db = await database;
    final maps = await db.query(
      'tasks',
      where: 'syncStatus = ?',
      whereArgs: [SyncStatus.pending.toString()],
    );

    return maps.map((map) => Task.fromMap(map)).toList();
  }

  /// Buscar tarefas com conflito
  Future<List<Task>> getConflictedTasks() async {
    final db = await database;
    final maps = await db.query(
      'tasks',
      where: 'syncStatus = ?',
      whereArgs: [SyncStatus.conflict.toString()],
    );

    return maps.map((map) => Task.fromMap(map)).toList();
  }

  /// Deletar tarefa
  Future<int> deleteTask(String id) async {
    final db = await database;
    return await db.delete(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Atualizar status de sincronização
  Future<void> updateSyncStatus(String id, SyncStatus status) async {
    final db = await database;
    await db.update(
      'tasks',
      {'syncStatus': status.toString()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== FILA DE SINCRONIZAÇÃO ====================

  /// Adicionar operação à fila
  Future<SyncOperation> addToSyncQueue(SyncOperation operation) async {
    final db = await database;
    await db.insert(
      'sync_queue',
      operation.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return operation;
  }

  /// Obter operações pendentes
  Future<List<SyncOperation>> getPendingSyncOperations() async {
    final db = await database;
    final maps = await db.query(
      'sync_queue',
      where: 'status = ?',
      whereArgs: [SyncOperationStatus.pending.toString()],
      orderBy: 'timestamp ASC',
    );

    return maps.map((map) => SyncOperation.fromMap(map)).toList();
  }

  /// Atualizar operação de sincronização
  Future<void> updateSyncOperation(SyncOperation operation) async {
    final db = await database;
    await db.update(
      'sync_queue',
      operation.toMap(),
      where: 'id = ?',
      whereArgs: [operation.id],
    );
  }

  /// Remover operação da fila
  Future<int> removeSyncOperation(String id) async {
    final db = await database;
    return await db.delete(
      'sync_queue',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Limpar operações concluídas
  Future<int> clearCompletedOperations() async {
    final db = await database;
    return await db.delete(
      'sync_queue',
      where: 'status = ?',
      whereArgs: [SyncOperationStatus.completed.toString()],
    );
  }

  // ==================== METADADOS ====================

  /// Salvar metadado
  Future<void> setMetadata(String key, String value) async {
    final db = await database;
    await db.insert(
      'metadata',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Obter metadado
  Future<String?> getMetadata(String key) async {
    final db = await database;
    final maps = await db.query(
      'metadata',
      where: 'key = ?',
      whereArgs: [key],
    );

    if (maps.isEmpty) return null;
    return maps.first['value'] as String;
  }

  // ==================== ESTATÍSTICAS ====================

  /// Obter estatísticas do banco de dados
  Future<Map<String, dynamic>> getStats() async {
    final db = await database;
    
    final totalTasks = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM tasks')
    ) ?? 0;
    
    final unsyncedTasks = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM tasks WHERE syncStatus = ?',
        [SyncStatus.pending.toString()]
      )
    ) ?? 0;
    
    final queuedOperations = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM sync_queue WHERE status = ?',
        [SyncOperationStatus.pending.toString()]
      )
    ) ?? 0;
    
    final lastSync = await getMetadata('lastSyncTimestamp');

    return {
      'totalTasks': totalTasks,
      'unsyncedTasks': unsyncedTasks,
      'queuedOperations': queuedOperations,
      'lastSync': lastSync != null ? int.parse(lastSync) : null,
    };
  }

  // ==================== UTILIDADES ====================

  /// Limpar todos os dados
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('tasks');
    await db.delete('sync_queue');
    await db.delete('metadata');
    print('🗑️ Todos os dados foram limpos');
  }

  /// Fechar banco de dados
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}