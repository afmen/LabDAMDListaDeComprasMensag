import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/shopping_list.dart';
import '../models/shopping_item.dart';

class ApiService {
  // Use 10.0.2.2 para Android Emulator
  static const String baseUrl = 'http://10.0.2.2:3000/api'; 
  String? _authToken;

  Future<void> authenticate() async {
    if (_authToken != null) return;
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'identifier': 'admin@microservices.com', 'password': 'admin123'}),
      );
      if (response.statusCode == 200) {
        _authToken = json.decode(response.body)['data']['token'];
      }
    } catch (e) {
      print('❌ Erro auth: $e');
    }
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $_authToken',
  };

  // --- Listas ---
  Future<List<ShoppingList>> getLists() async {
    await authenticate();
    if (_authToken == null) throw Exception('Offline/Não autenticado');
    final response = await http.get(Uri.parse('$baseUrl/lists'), headers: _headers);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['data'] as List).map((json) => ShoppingList.fromJson(json)).toList();
    }
    throw Exception('Erro getLists');
  }

  Future<ShoppingList> createList(ShoppingList list) async {
    await authenticate();
    final response = await http.post(Uri.parse('$baseUrl/lists'), headers: _headers, body: json.encode(list.toJson()));
    if (response.statusCode == 201) return ShoppingList.fromJson(json.decode(response.body)['data']);
    throw Exception('Erro createList');
  }

  Future<ShoppingList> updateList(ShoppingList list) async {
    await authenticate();
    final response = await http.put(Uri.parse('$baseUrl/lists/${list.id}'), headers: _headers, body: json.encode(list.toJson()));
    if (response.statusCode == 200) return ShoppingList.fromJson(json.decode(response.body)['data']);
    throw Exception('Erro updateList');
  }

  Future<void> deleteList(String id) async {
    await authenticate();
    await http.delete(Uri.parse('$baseUrl/lists/$id'), headers: _headers);
  }

  // --- NOVOS: Itens ---
  // O backend espera: POST /lists/:id/items
  Future<void> addItem(String listId, ShoppingItem item) async {
    await authenticate();
    // O backend tem um prefixo duplo por causa do gateway: /api/lists/lists/:id/items
    final response = await http.post(
      Uri.parse('$baseUrl/lists/lists/$listId/items'), 
      headers: _headers,
      body: json.encode(item.toJson()),
    );
    if (response.statusCode != 201) throw Exception('Erro addItem: ${response.statusCode}');
  }

  // PUT /lists/:id/items/:itemId
  Future<void> updateItem(String listId, ShoppingItem item) async {
    await authenticate();
    final response = await http.put(
      Uri.parse('$baseUrl/lists/lists/$listId/items/${item.id}'),
      headers: _headers,
      body: json.encode(item.toJson()),
    );
    if (response.statusCode != 200) throw Exception('Erro updateItem');
  }

  // DELETE /lists/:id/items/:itemId
  Future<void> deleteItem(String listId, String itemId) async {
    await authenticate();
    final response = await http.delete(
      Uri.parse('$baseUrl/lists/lists/$listId/items/$itemId'),
      headers: _headers,
    );
    if (response.statusCode != 200) throw Exception('Erro deleteItem');
  }
}