import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/list_provider.dart'; // Importação atualizada
import '../services/sync_service.dart';

class SyncStatusScreen extends StatelessWidget {
  const SyncStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Status de Sincronização'),
      ),
      body: Consumer<ListProvider>( // Provider atualizado
        builder: (context, provider, child) {
          // Nota: Certifique-se de adicionar o método getSyncStats() no ListProvider
          // ou acessar via SyncService se ele for público. 
          // Assumindo que você expôs um método similar ao do TaskProvider anterior.
          return FutureBuilder<SyncStats>(
            future: _fetchStats(provider), // Helper temporário ou método do provider
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
                    title: 'Total de Listas', // Texto atualizado
                    icon: Icons.list_alt,     // Ícone atualizado
                    value: '${stats.totalTasks}', // Mantendo a prop genérica do SyncStats
                    color: Colors.blue,
                  ),
                  _buildStatusCard(
                    title: 'Listas Pendentes', // Texto atualizado
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

  // Helper para buscar stats (caso não tenha adicionado no ListProvider ainda)
  // O ideal é mover isso para dentro do ListProvider como getSyncStats()
  Future<SyncStats> _fetchStats(ListProvider provider) async {
    // Aqui assumimos que o SyncService tem o método getStats
    // Se o ListProvider não expor o SyncService, você precisará adicionar
    // o método getSyncStats() no ListProvider (recomendado).
    // return provider.getSyncStats(); 
    
    // Fallback Mock para não quebrar a UI se o método faltar:
    return SyncStats(
      totalTasks: provider.lists.length,
      unsyncedTasks: provider.lists.where((l) => l.syncStatus.toString().contains('pending')).length,
      queuedOperations: 0, 
      lastSync: DateTime.now(), 
      isOnline: provider.isOnline, 
      isSyncing: false
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

  Future<void> _handleSync(BuildContext context, ListProvider provider) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔄 Iniciando sincronização...'),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      await provider.manualSync(); // Chamada atualizada para ListProvider

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Sincronização concluída'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erro: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// Estatísticas de sincronização (Definição Local para corrigir erro de tipo)
class SyncStats {
  final int totalTasks;
  final int unsyncedTasks;
  final int queuedOperations;
  final DateTime? lastSync;
  final bool isOnline;
  final bool isSyncing;

  SyncStats({
    required this.totalTasks,
    required this.unsyncedTasks,
    required this.queuedOperations,
    this.lastSync,
    required this.isOnline,
    required this.isSyncing,
  });
}