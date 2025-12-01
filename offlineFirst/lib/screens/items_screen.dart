import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/shopping_list.dart';
import '../providers/list_provider.dart';

class ItemsScreen extends StatefulWidget {
  final ShoppingList list;

  const ItemsScreen({super.key, required this.list});

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  @override
  void initState() {
    super.initState();
    // Carrega os itens ao abrir a tela
    Future.microtask(() => 
      context.read<ListProvider>().loadItems(widget.list.id)
    );
  }

  void _showAddItemDialog(BuildContext context) {
    final nameController = TextEditingController();
    final qtyController = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adicionar Produto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nome do produto (ex: Leite)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantidade',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                final qty = double.tryParse(qtyController.text) ?? 1.0;
                context.read<ListProvider>().addItem(
                  widget.list.id, 
                  nameController.text, 
                  qty
                );
                Navigator.pop(ctx);
              }
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.list.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<ListProvider>().loadItems(widget.list.id),
          )
        ],
      ),
      body: Consumer<ListProvider>(
        builder: (context, provider, child) {
          final items = provider.currentItems;
          
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_basket_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text('Nenhum item na lista'),
                  const Text('Toque no + para adicionar'),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: items.length,
            padding: const EdgeInsets.only(bottom: 80), // Espaço para o FAB
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: Checkbox(
                    value: item.purchased,
                    onChanged: (_) => provider.toggleItem(item),
                  ),
                  title: Text(
                    item.name,
                    style: TextStyle(
                      decoration: item.purchased ? TextDecoration.lineThrough : null,
                      color: item.purchased ? Colors.grey : null,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Qtd: ${item.quantity} ${item.unit}',
                    style: TextStyle(
                      color: item.purchased ? Colors.grey : null,
                    ),
                  ),
                  trailing: item.syncStatus.toString().contains('pending')
                      ? const Tooltip(
                          message: 'Aguardando envio...',
                          child: Icon(Icons.cloud_upload, size: 20, color: Colors.orange),
                        )
                      : const Tooltip(
                          message: 'Sincronizado',
                          child: Icon(Icons.check_circle, size: 20, color: Colors.green),
                        ),
                ),
              );
            },
          );
        },
      ),
      // BOTÃO FLUTUANTE ADICIONADO AQUI
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddItemDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}