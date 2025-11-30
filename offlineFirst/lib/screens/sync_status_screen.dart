import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/task_provider.dart';
import '../services/sync_service.dart';

class SyncStatusScreen extends StatelessWidget {
  const SyncStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Status de Sincronização'),
      ),
      body: Consumer<TaskProvider>(
        builder: (context, provider, child) {
          return FutureBuilder<SyncStats>(
            future: provider.getSyncStats(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final stats = snapshot.data!;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildStatusCard(
                    title: 'Conectividade',
                    icon: Icons.wifi,
                    value: stats.isOnline ? 'Online' : 'Offline',
                    color: stats.isOnline ? Colors.green : Colors.red,
                  ),
                  _buildStatusCard(
                    title: 'Status de Sincronização',
                    icon: Icons.sync,
                    value: stats.isSyncing ? 'Sincronizando...' : 'Ocioso',
                    color: stats.isSyncing ? Colors.blue : Colors.grey,
                  ),
                  _buildStatusCard(
                    title: 'Total de Tarefas',
                    icon: Icons.task,
                    value: '${stats.totalTasks}',
                    color: Colors.blue,
                  ),
                  _buildStatusCard(
                    title: 'Tarefas Não Sincronizadas',
                    icon: Icons.cloud_off,
                    value: '${stats.unsyncedTasks}',
                    color: stats.unsyncedTasks > 0 ? Colors.orange : Colors.green,
                  ),
                  _buildStatusCard(
                    title: 'Operações na Fila',
                    icon: Icons.queue,
                    value: '${stats.queuedOperations}',
                    color: stats.queuedOperations > 0 ? Colors.orange : Colors.green,
                  ),
                  _buildStatusCard(
                    title: 'Última Sincronização',
                    icon: Icons.update,
                    value: stats.lastSync != null
                        ? DateFormat('dd/MM/yyyy HH:mm').format(stats.lastSync!)
                        : 'Nunca',
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: stats.isOnline && !stats.isSyncing
                        ? () => _handleSync(context, provider)
                        : null,
                    icon: const Icon(Icons.sync),
                    label: const Text('Sincronizar Agora'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatusCard({
    required String title,
    required IconData icon,
    required String value,
    required Color color,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSync(BuildContext context, TaskProvider provider) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔄 Iniciando sincronização...'),
        duration: Duration(seconds: 1),
      ),
    );

    final result = await provider.sync();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.success
                ? '✅ Sincronização concluída'
                : '❌ ${result.message}',
          ),
          backgroundColor: result.success ? Colors.green : Colors.red,
        ),
      );
    }
  }
}