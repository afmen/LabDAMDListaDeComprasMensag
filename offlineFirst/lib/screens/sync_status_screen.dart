import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/list_provider.dart';
import '../services/sync_service.dart'; // Importa SyncStats

class SyncStatusScreen extends StatelessWidget {
  const SyncStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Status de Sincronização'),
      ),
      body: Consumer<ListProvider>(
        builder: (context, provider, child) {
          return FutureBuilder<SyncStats>(
            future: provider.getSyncStats(), // Usa o método real do provider
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (snapshot.hasError) {
                return Center(child: Text("Erro ao carregar status: ${snapshot.error}"));
              }

              if (!snapshot.hasData) {
                return const Center(child: Text("Sem dados disponíveis"));
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
                    title: 'Total de Listas',
                    icon: Icons.list_alt,
                    value: '${stats.totalLists}', // Nome corrigido conforme SyncStats em sync_service.dart
                    color: Colors.blue,
                  ),
                  _buildStatusCard(
                    title: 'Listas Pendentes',
                    icon: Icons.cloud_off,
                    value: '${stats.unsyncedLists}',
                    color: stats.unsyncedLists > 0 ? Colors.orange : Colors.green,
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

  Future<void> _handleSync(BuildContext context, ListProvider provider) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔄 Iniciando sincronização...'),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      await provider.manualSync();
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