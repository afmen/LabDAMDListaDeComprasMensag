import 'package:flutter/foundation.dart';
import '../models/task.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';

/// Provider para gerenciamento de estado de tarefas
class TaskProvider with ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;
  final SyncService _syncService;

  List<Task> _tasks = [];
  bool _isLoading = false;
  String? _error;

  TaskProvider({String userId = 'user1'})
      : _syncService = SyncService(userId: userId);

  // Getters
  List<Task> get tasks => _tasks;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  List<Task> get completedTasks =>
      _tasks.where((task) => task.completed).toList();
  
  List<Task> get pendingTasks =>
      _tasks.where((task) => !task.completed).toList();
  
  List<Task> get unsyncedTasks =>
      _tasks.where((task) => task.syncStatus == SyncStatus.pending).toList();

  // ==================== INICIALIZAÇÃO ====================

  Future<void> initialize() async {
    await loadTasks();
    
    // Iniciar auto-sync
    _syncService.startAutoSync();
    
    // Escutar eventos de sincronização
    _syncService.syncStatusStream.listen((event) {
      if (event.type == SyncEventType.completed) {
        loadTasks(); // Recarregar tarefas após sync
      }
    });
  }

  // ==================== OPERAÇÕES DE TAREFAS ====================

  /// Carregar todas as tarefas
  Future<void> loadTasks() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _tasks = await _db.getAllTasks();
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Criar nova tarefa
  Future<void> createTask({
    required String title,
    required String description,
    String priority = 'medium',
  }) async {
    try {
      final task = Task(
        title: title,
        description: description,
        priority: priority,
      );

      await _syncService.createTask(task);
      await loadTasks();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Atualizar tarefa
  Future<void> updateTask(Task task) async {
    try {
      await _syncService.updateTask(task);
      await loadTasks();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Alternar status de conclusão
  Future<void> toggleCompleted(Task task) async {
    await updateTask(task.copyWith(completed: !task.completed));
  }

  /// Deletar tarefa
  Future<void> deleteTask(String taskId) async {
    try {
      await _syncService.deleteTask(taskId);
      await loadTasks();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // ==================== SINCRONIZAÇÃO ====================

  /// Sincronizar manualmente
  Future<SyncResult> sync() async {
    final result = await _syncService.sync();
    await loadTasks();
    return result;
  }

  /// Obter estatísticas de sincronização
  Future<SyncStats> getSyncStats() async {
    return await _syncService.getStats();
  }

  // ==================== LIMPEZA ====================

  @override
  void dispose() {
    _syncService.dispose();
    super.dispose();
  }
}