import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/list_provider.dart';
import '../models/shopping_list.dart';
import 'task_form_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ListProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Minhas Compras'),
            backgroundColor: provider.isOnline ? Colors.green : Colors.red,
            actions: [
              IconButton(
                icon: Icon(provider.isOnline ? Icons.wifi : Icons.wifi_off),
                onPressed: () {},
                tooltip: provider.isOnline ? 'Online' : 'Offline Mode',
              ),
              IconButton(
                icon: const Icon(Icons.sync),
                onPressed: provider.isOnline ? () => provider.manualSync() : null,
              )
            ],
          ),
          body: Column(
            children: [
              if (!provider.isOnline)
                Container(
                  color: Colors.red[100],
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  child: const Text(
                    '⚠️ Modo Offline - Alterações serão sincronizadas depois',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  itemCount: provider.lists.length,
                  itemBuilder: (context, index) {
                    final list = provider.lists[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: list.status == 'completed' ? Colors.grey : Colors.blue,
                        child: Icon(Icons.shopping_cart, color: Colors.white),
                      ),
                      title: Text(
                        list.name,
                        style: TextStyle(
                          decoration: list.status == 'completed' 
                              ? TextDecoration.lineThrough 
                              : null,
                        ),
                      ),
                      subtitle: Text(list.description),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Ícone de Status de Sincronização
                          if (list.syncStatus == SyncStatus.pending)
                            const Icon(Icons.cloud_off, color: Colors.orange)
                          else if (list.syncStatus == SyncStatus.synced)
                            const Icon(Icons.check_circle, color: Colors.green),
                          
                          PopupMenuButton(
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'edit', child: Text('Editar')),
                              const PopupMenuItem(value: 'delete', child: Text('Excluir')),
                              PopupMenuItem(
                                value: 'toggle', 
                                child: Text(list.status == 'active' ? 'Finalizar' : 'Reabrir')
                              ),
                            ],
                            onSelected: (value) {
                              if (value == 'delete') {
                                provider.deleteList(list.id);
                              } else if (value == 'edit') {
                                Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => TaskFormScreen(list: list),
                                ));
                              } else if (value == 'toggle') {
                                provider.updateList(list.copyWith(
                                  status: list.status == 'active' ? 'completed' : 'active'
                                ));
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: provider.isOnline ? Colors.green : Colors.orange,
            child: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => const TaskFormScreen(),
              ));
            },
          ),
        );
      },
    );
  }
}