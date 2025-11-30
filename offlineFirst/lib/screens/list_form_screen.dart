import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/shopping_list.dart';
import '../providers/list_provider.dart';

class ListFormScreen extends StatefulWidget {
  final ShoppingList? list;

  const ListFormScreen({super.key, this.list});

  @override
  State<ListFormScreen> createState() => _ListFormScreenState();
}

class _ListFormScreenState extends State<ListFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.list?.name ?? '');
    _descController = TextEditingController(text: widget.list?.description ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.list == null ? 'Nova Lista' : 'Editar Lista')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Nome da Lista (ex: Mercado Semanal)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Nome é obrigatório' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: 'Descrição / Observações',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveList,
                  icon: const Icon(Icons.save),
                  label: const Text('Salvar'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _saveList() {
    if (_formKey.currentState!.validate()) {
      final provider = context.read<ListProvider>();
      
      if (widget.list == null) {
        provider.addList(_titleController.text, _descController.text);
      } else {
        provider.updateList(widget.list!.copyWith(
          name: _titleController.text,
          description: _descController.text,
        ));
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lista salva com sucesso!')),
        );
        Navigator.pop(context);
      }
    }
  }
}