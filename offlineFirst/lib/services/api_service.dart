import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/shopping_list.dart';

class ApiService {
  // Use 10.0.2.2 para Android Emulator, localhost para iOS
  static const String baseUrl = 'http://10.0.2.2:3000/api'; 
  String? _authToken;

  // Autenticação Automática para Demo
  Future<void> authenticate() async {
    if (_authToken != null) return;

    try {
      print('🔐 Autenticando usuário demo...');
      final response = await http.post(
        Uri.parse('$baseUrl/users/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'identifier': 'admin@microservices.com',
          'password': 'admin123'
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _authToken = data['data']['token'];
        print('✅ Autenticado! Token obtido.');
      } else {
        print('❌ Falha na autenticação: ${response.body}');
      }
    } catch (e) {
      print('❌ Erro de conexão no login: $e');
    }
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $_authToken',
  };

  Future<List<ShoppingList>> getLists() async {
    await authenticate();
    if (_authToken == null) throw Exception('Não autenticado');

    final response = await http.get(Uri.parse('$baseUrl/lists'), headers: _headers);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['data'] as List)
          .map((json) => ShoppingList.fromJson(json))
          .toList();
    }
    throw Exception('Erro ao buscar listas: ${response.statusCode}');
  }

  Future<ShoppingList> createList(ShoppingList list) async {
    await authenticate();
    final response = await http.post(
      Uri.parse('$baseUrl/lists'),
      headers: _headers,
      body: json.encode(list.toJson()),
    );

    if (response.statusCode == 201) {
      final data = json.decode(response.body);
      return ShoppingList.fromJson(data['data']);
    }
    throw Exception('Erro ao criar lista: ${response.statusCode}');
  }

  Future<ShoppingList> updateList(ShoppingList list) async {
    await authenticate();
    final response = await http.put(
      Uri.parse('$baseUrl/lists/${list.id}'),
      headers: _headers,
      body: json.encode(list.toJson()),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return ShoppingList.fromJson(data['data']);
    }
    throw Exception('Erro ao atualizar lista: ${response.statusCode}');
  }

  Future<void> deleteList(String id) async {
    await authenticate();
    final response = await http.delete(
      Uri.parse('$baseUrl/lists/$id'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Erro ao deletar lista');
    }
  }
}