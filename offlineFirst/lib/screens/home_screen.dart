import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/list_provider.dart';
import '../models/shopping_list.dart';
import 'list_form_screen.dart'; // Importação corrigida

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
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: Icon(provider.isOnline ? Icons.wifi : Icons.wifi_off),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(provider.isOnline ? 'Online' : 'Offline')),
                  );
                },
                tooltip: provider.isOnline ? 'Online' : 'Offline Mode',
              ),
              IconButton(
                icon: const Icon(Icons.sync),
                onPressed: provider.isOnline ? () => provider.manualSync() : null,
                tooltip: 'Sincronizar Agora',
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.cloud_off, size: 16, color: Colors.red),
                      SizedBox(width: 8),
                      Text(
                        'Modo Offline - Alterações locais',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: provider.lists.isEmpty 
                  ? const Center(child: Text('Nenhuma lista criada'))
                  : ListView.builder(
                      itemCount: provider.lists.length,
                      itemBuilder: (context, index) {
                        final list = provider.lists[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: list.status == 'completed' ? Colors.grey : Colors.green,
                            child: const Icon(Icons.shopping_cart, color: Colors.white),
                          ),
                          title: Text(
                            list.name,
                            style: TextStyle(
                              decoration: list.status == 'completed' 
                                  ? TextDecoration.lineThrough 
                                  : null,
                              color: list.status == 'completed' ? Colors.grey : null,
                            ),
                          ),
                          subtitle: Text(
                            list.description.isNotEmpty ? list.description : 'Sem descrição',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Ícone de Status de Sincronização
                              if (list.syncStatus == SyncStatus.pending)
                                const Tooltip(
                                  message: 'Pendente de envio',
                                  child: Icon(Icons.cloud_upload, color: Colors.orange),
                                )
                              else if (list.syncStatus == SyncStatus.synced)
                                const Tooltip(
                                  message: 'Sincronizado',
                                  child: Icon(Icons.check_circle, color: Colors.green),
                                ),
                              
                              PopupMenuButton<String>(
                                itemBuilder: (context) => [
                                  const PopupMenuItem(value: 'edit', child: Text('Editar')),
                                  PopupMenuItem(
                                    value: 'toggle', 
                                    child: Text(list.status == 'active' ? 'Finalizar' : 'Reabrir')
                                  ),
                                  const PopupMenuItem(value: 'delete', child: Text('Excluir', style: TextStyle(color: Colors.red))),
                                ],
                                onSelected: (value) {
                                  if (value == 'delete') {
                                    _confirmDelete(context, provider, list.id);
                                  } else if (value == 'edit') {
                                    Navigator.push(context, MaterialPageRoute(
                                      builder: (_) => ListFormScreen(list: list), // Usa a nova tela
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
                          onTap: () {
                            // Futuro: Navegar para os itens da lista
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Abrir itens de "${list.name}"')),
                            );
                          },
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
                builder: (_) => const ListFormScreen(), // Usa a nova tela
              ));
            },
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, ListProvider provider, String listId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Lista?'),
        content: const Text('Esta ação não pode ser desfeita e será sincronizada quando houver internet.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              provider.deleteList(listId);
              Navigator.pop(ctx);
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}