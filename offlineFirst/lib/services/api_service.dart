import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/task.dart';

/// Serviço de comunicação com API REST do servidor
class ApiService {
  static const String baseUrl = 'http://10.0.2.2:3000/api'; // Android emulator
  // static const String baseUrl = 'http://localhost:3000/api'; // iOS simulator
  
  final String userId;

  ApiService({this.userId = 'user1'});

  // ==================== OPERAÇÕES DE TAREFAS ====================

  /// Buscar todas as tarefas (com sync incremental)
  Future<Map<String, dynamic>> getTasks({int? modifiedSince}) async {
    try {
      final uri = Uri.parse('$baseUrl/tasks').replace(
        queryParameters: {
          'userId': userId,
          if (modifiedSince != null) 'modifiedSince': modifiedSince.toString(),
        },
      );

      final response = await http.get(uri).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'tasks': (data['tasks'] as List)
              .map((json) => Task.fromJson(json))
              .toList(),
          'lastSync': data['lastSync'],
          'serverTime': data['serverTime'],
        };
      } else {
        throw Exception('Erro ao buscar tarefas: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Erro na requisição getTasks: $e');
      rethrow;
    }
  }

  /// Criar tarefa no servidor
  Future<Task> createTask(Task task) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/tasks'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(task.toJson()),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return Task.fromJson(data['task']);
      } else {
        throw Exception('Erro ao criar tarefa: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Erro na requisição createTask: $e');
      rethrow;
    }
  }

  /// Atualizar tarefa no servidor
  Future<Map<String, dynamic>> updateTask(Task task) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/tasks/${task.id}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          ...task.toJson(),
          'version': task.version,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'task': Task.fromJson(data['task']),
        };
      } else if (response.statusCode == 409) {
        // Conflito detectado
        final data = json.decode(response.body);
        return {
          'success': false,
          'conflict': true,
          'serverTask': Task.fromJson(data['serverTask']),
        };
      } else {
        throw Exception('Erro ao atualizar tarefa: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Erro na requisição updateTask: $e');
      rethrow;
    }
  }

  /// Deletar tarefa no servidor
  Future<bool> deleteTask(String id, int version) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/tasks/$id?version=$version'),
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200 || response.statusCode == 404;
    } catch (e) {
      print('❌ Erro na requisição deleteTask: $e');
      rethrow;
    }
  }

  /// Sincronização em lote
  Future<List<Map<String, dynamic>>> syncBatch(
    List<Map<String, dynamic>> operations,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/sync/batch'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'operations': operations}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['results']);
      } else {
        throw Exception('Erro no sync em lote: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Erro na requisição syncBatch: $e');
      rethrow;
    }
  }

  /// Verificar conectividade com servidor
  Future<bool> checkConnectivity() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}