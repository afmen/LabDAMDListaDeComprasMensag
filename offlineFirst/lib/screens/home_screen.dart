import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/list_provider.dart';
import '../models/shopping_list.dart';
import 'list_form_screen.dart';
import 'items_screen.dart'; // Certifique-se de que este arquivo existe

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ListProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Minhas Compras',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: provider.isOnline ? Colors.green : Colors.red,
            actions: [
              // Indicador Visual de Conectividade
              IconButton(
                icon: Icon(
                  provider.isOnline ? Icons.wifi : Icons.wifi_off,
                  color: Colors.white,
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(provider.isOnline ? 'Você está Online' : 'Modo Offline Ativado'),
                      backgroundColor: provider.isOnline ? Colors.green : Colors.red,
                    ),
                  );
                },
                tooltip: provider.isOnline ? 'Online' : 'Offline Mode',
              ),
              // Botão de Sincronização Manual
              IconButton(
                icon: const Icon(Icons.sync, color: Colors.white),
                onPressed: provider.isOnline ? () => provider.manualSync() : null,
                tooltip: 'Sincronizar Agora',
              )
            ],
          ),
          body: Column(
            children: [
              // Faixa de Aviso Offline (aparece apenas quando sem internet)
              if (!provider.isOnline)
                Container(
                  color: Colors.red[100],
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.cloud_off, size: 14, color: Colors.red),
                      SizedBox(width: 8),
                      Text(
                        'Modo Offline - Alterações salvas localmente',
                        style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              
              // Lista de Listas de Compras
              Expanded(
                child: provider.lists.isEmpty 
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_basket_outlined, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'Nenhuma lista criada',
                            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Toque no + para criar sua primeira lista',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: provider.lists.length,
                      itemBuilder: (context, index) {
                        final list = provider.lists[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          elevation: 2,
                          child: ListTile(
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
                                fontWeight: FontWeight.bold,
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
                                // Ícone de Status de Sincronização (Nuvem ou Check)
                                if (list.syncStatus == SyncStatus.pending)
                                  const Tooltip(
                                    message: 'Pendente de envio',
                                    child: Padding(
                                      padding: EdgeInsets.only(right: 8.0),
                                      child: Icon(Icons.cloud_upload, color: Colors.orange),
                                    ),
                                  )
                                else if (list.syncStatus == SyncStatus.synced)
                                  const Tooltip(
                                    message: 'Sincronizado',
                                    child: Padding(
                                      padding: EdgeInsets.only(right: 8.0),
                                      child: Icon(Icons.check_circle, color: Colors.green),
                                    ),
                                  ),
                                
                                // Menu de Opções (Editar/Excluir/Finalizar)
                                PopupMenuButton<String>(
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'edit', 
                                      child: ListTile(
                                        leading: Icon(Icons.edit), 
                                        title: Text('Editar'),
                                        contentPadding: EdgeInsets.zero,
                                      )
                                    ),
                                    PopupMenuItem(
                                      value: 'toggle', 
                                      child: ListTile(
                                        leading: Icon(list.status == 'active' ? Icons.check : Icons.refresh), 
                                        title: Text(list.status == 'active' ? 'Finalizar' : 'Reabrir'),
                                        contentPadding: EdgeInsets.zero,
                                      )
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete', 
                                      child: ListTile(
                                        leading: Icon(Icons.delete, color: Colors.red), 
                                        title: Text('Excluir', style: TextStyle(color: Colors.red)),
                                        contentPadding: EdgeInsets.zero,
                                      )
                                    ),
                                  ],
                                  onSelected: (value) {
                                    if (value == 'delete') {
                                      _confirmDelete(context, provider, list.id);
                                    } else if (value == 'edit') {
                                      Navigator.push(context, MaterialPageRoute(
                                        builder: (_) => ListFormScreen(list: list),
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
                              // Navega para a tela de itens da lista
                              Navigator.push(context, MaterialPageRoute(
                                builder: (_) => ItemsScreen(list: list),
                              ));
                            },
                          ),
                        );
                      },
                    ),
              ),
            ],
          ),
          // =======================================================
          // AQUI ESTÁ O BOTÃO QUE FALTAVA (FLOATING ACTION BUTTON)
          // =======================================================
          floatingActionButton: FloatingActionButton(
            backgroundColor: provider.isOnline ? Colors.green : Colors.orange,
            tooltip: 'Criar Nova Lista',
            child: const Icon(Icons.add, color: Colors.white),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => const ListFormScreen(),
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
        content: const Text('Esta ação não pode ser desfeita. Se estiver offline, a exclusão será sincronizada quando houver internet.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text('Cancelar')
          ),
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