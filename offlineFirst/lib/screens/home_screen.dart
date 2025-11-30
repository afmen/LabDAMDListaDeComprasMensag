import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/task_provider.dart';
import '../models/task.dart';
import '../services/connectivity_service.dart';
import 'task_form_screen.dart';
import 'sync_status_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _connectivity = ConnectivityService.instance;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _initializeConnectivity();
  }

  Future<void> _initializeConnectivity() async {
    await _connectivity.initialize();
    setState(() => _isOnline = _connectivity.isOnline);
    
    // Escutar mudanças de conectividade
    _connectivity.connectivityStream.listen((isOnline) {
      setState(() => _isOnline = isOnline);
      
      if (isOnline) {
        _showSnackBar('🟢 Conectado - Sincronizando...', Colors.green);
        context.read<TaskProvider>().sync();
      } else {
        _showSnackBar('🔴 Modo Offline', Colors.orange);
      }
    });
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tarefas Offline-First'),
        actions: [
          // Indicador de conectividade
          _buildConnectivityIndicator(),
          
          // Botão de sincronização manual
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _isOnline ? _handleManualSync : null,
            tooltip: 'Sincronizar',
          ),
          
          // Botão de estatísticas
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _navigateToSyncStatus(),
            tooltip: 'Status de Sincronização',
          ),
        ],
      ),
      body: Consumer<TaskProvider>(
        builder: (context, taskProvider, child) {
          if (taskProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (taskProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Erro: ${taskProvider.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => taskProvider.loadTasks(),
                    child: const Text('Tentar Novamente'),
                  ),
                ],
              ),
            );
          }

          final tasks = taskProvider.tasks;

          if (tasks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhuma tarefa',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Toque em + para criar',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => taskProvider.sync(),
            child: ListView.builder(
              itemCount: tasks.length,
              padding: const EdgeInsets.all(8),
              itemBuilder: (context, index) {
                final task = tasks[index];
                return _buildTaskCard(task, taskProvider);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToTaskForm,
        child: const Icon(Icons.add),
        tooltip: 'Nova Tarefa',
      ),
    );
  }

  Widget _buildConnectivityIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Center(
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isOnline ? Colors.green : Colors.red,
          ),
        ),
      ),
    );
  }

  Widget _buildTaskCard(Task task, TaskProvider provider) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: Checkbox(
          value: task.completed,
          onChanged: (_) => provider.toggleCompleted(task),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            decoration: task.completed ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.description.isNotEmpty)
              Text(
                task.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                _buildPriorityBadge(task.priority),
                const SizedBox(width: 8),
                _buildSyncStatusBadge(task.syncStatus),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _navigateToTaskForm(task: task),
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _confirmDelete(task, provider),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityBadge(String priority) {
    Color color;
    switch (priority) {
      case 'urgent':
        color = Colors.red;
        break;
      case 'high':
        color = Colors.orange;
        break;
      case 'medium':
        color = Colors.blue;
        break;
      case 'low':
        color = Colors.green;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        priority.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildSyncStatusBadge(SyncStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _getSyncStatusColor(status).withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.icon,
        style: const TextStyle(fontSize: 10),
      ),
    );
  }

  Color _getSyncStatusColor(SyncStatus status) {
    switch (status) {
      case SyncStatus.synced:
        return Colors.green;
      case SyncStatus.pending:
        return Colors.orange;
      case SyncStatus.conflict:
        return Colors.red;
      case SyncStatus.error:
        return Colors.red;
    }
  }

  Future<void> _handleManualSync() async {
    final provider = context.read<TaskProvider>();
    
    _showSnackBar('🔄 Sincronizando...', Colors.blue);
    
    final result = await provider.sync();
    
    if (result.success) {
      _showSnackBar(
        '✅ Sincronização concluída',
        Colors.green,
      );
    } else {
      _showSnackBar(
        '❌ Erro na sincronização',
        Colors.red,
      );
    }
  }

  void _navigateToTaskForm({Task? task}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TaskFormScreen(task: task),
      ),
    );
  }

  void _navigateToSyncStatus() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SyncStatusScreen(),
      ),
    );
  }

  Future<void> _confirmDelete(Task task, TaskProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text('Deseja deletar "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Deletar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await provider.deleteTask(task.id);
      if (mounted) {
        _showSnackBar('🗑️ Tarefa deletada', Colors.grey);
      }
    }
  }
}