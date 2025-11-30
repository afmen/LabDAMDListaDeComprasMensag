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
  final _itemController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Carrega os itens ao abrir a tela
    Future.microtask(() => 
      context.read<ListProvider>().loadItems(widget.list.id)
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.list.name)),
      body: Column(
        children: [
          // Campo de Adicionar Rápido
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _itemController,
                    decoration: const InputDecoration(
                      hintText: 'Adicionar produto (ex: Leite)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
                  onPressed: () {
                    if (_itemController.text.isNotEmpty) {
                      context.read<ListProvider>().addItem(
                        widget.list.id, 
                        _itemController.text, 
                        1.0
                      );
                      _itemController.clear();
                    }
                  },
                )
              ],
            ),
          ),
          
          // Lista de Itens
          Expanded(
            child: Consumer<ListProvider>(
              builder: (context, provider, child) {
                final items = provider.currentItems;
                if (items.isEmpty) return const Center(child: Text('Lista vazia'));

                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      leading: Checkbox(
                        value: item.purchased,
                        onChanged: (_) => provider.toggleItem(item),
                      ),
                      title: Text(
                        item.name,
                        style: TextStyle(
                          decoration: item.purchased ? TextDecoration.lineThrough : null,
                          color: item.purchased ? Colors.grey : null,
                        ),
                      ),
                      subtitle: Text('${item.quantity} ${item.unit}'),
                      trailing: item.syncStatus.toString().contains('pending')
                          ? const Icon(Icons.cloud_upload, size: 16, color: Colors.orange)
                          : const Icon(Icons.check, size: 16, color: Colors.green),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}