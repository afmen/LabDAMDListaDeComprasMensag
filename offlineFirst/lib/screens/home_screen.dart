import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/list_provider.dart';
import '../models/shopping_list.dart';
import 'list_form_screen.dart';
import 'items_screen.dart'; // Importe a nova tela

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ListProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          // ... (AppBar e Header igual) ...
          appBar: AppBar(
            title: const Text('Minhas Compras'),
            backgroundColor: provider.isOnline ? Colors.green : Colors.red,
            // ... actions
          ),
          body: Column(
            children: [
              // ... (Container Offline igual) ...
              Expanded(
                child: ListView.builder(
                  itemCount: provider.lists.length,
                  itemBuilder: (context, index) {
                    final list = provider.lists[index];
                    return ListTile(
                      // ... (Visual igual) ...
                      title: Text(list.name),
                      trailing: Row(
                         // ... (Ícones de status igual)
                         children: [], // Mantenha os ícones
                      ),
                      onTap: () {
                        // NAVEGAÇÃO PARA ITENS
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => ItemsScreen(list: list),
                        ));
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          // ... (FAB igual)
        );
      },
    );
  }
}