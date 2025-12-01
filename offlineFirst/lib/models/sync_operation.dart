import 'dart:convert';
import 'package:uuid/uuid.dart';

/// Operação de sincronização pendente
class SyncOperation {
  final String id;
  final OperationType type;
  final String taskId;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final int retries;
  final SyncOperationStatus status;
  final String? error;

  SyncOperation({
    String? id,
    required this.type,
    required this.taskId,
    required this.data,
    DateTime? timestamp,
    this.retries = 0,
    this.status = SyncOperationStatus.pending,
    this.error,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  /// Criar cópia com modificações
  SyncOperation copyWith({
    OperationType? type,
    String? taskId,
    Map<String, dynamic>? data,
    DateTime? timestamp,
    int? retries,
    SyncOperationStatus? status,
    String? error,
  }) {
    return SyncOperation(
      id: id,
      type: type ?? this.type,
      taskId: taskId ?? this.taskId,
      data: data ?? this.data,
      timestamp: timestamp ?? this.timestamp,
      retries: retries ?? this.retries,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }

  /// Converter para Map (para banco de dados)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.toString(),
      'taskId': taskId,
      'data': json.encode(data), // Garante JSON válido ao salvar
      'timestamp': timestamp.millisecondsSinceEpoch,
      'retries': retries,
      'status': status.toString(),
      'error': error,
    };
  }

  /// Criar a partir de Map (do banco de dados)
  factory SyncOperation.fromMap(Map<String, dynamic> map) {
    return SyncOperation(
      id: map['id'],
      type: OperationType.values.firstWhere(
        (e) => e.toString() == map['type'],
        orElse: () => OperationType.update,
      ),
      taskId: map['taskId'],
      data: _parseData(map['data']), // Tenta parse robusto
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      retries: map['retries'],
      status: SyncOperationStatus.values.firstWhere(
        (e) => e.toString() == map['status'],
        orElse: () => SyncOperationStatus.pending,
      ),
      error: map['error'],
    );
  }

  static Map<String, dynamic> _parseData(dynamic data) {
    if (data == null) return {};
    if (data is Map<String, dynamic>) return data;
    
    if (data is String) {
      if (data.isEmpty) return {};
      try {
        // Tenta decodificar JSON padrão
        return json.decode(data) as Map<String, dynamic>;
      } catch (e) {
        // Fallback: Tenta recuperar dados salvos com .toString() (formato {key: value})
        // Isso é necessário porque versões anteriores salvaram dados incorretamente
        try {
          print('⚠️ Tentando recuperar dados mal formatados: $data');
          // Remove chaves externas e divide por vírgula
          String cleanData = data.trim();
          if (cleanData.startsWith('{') && cleanData.endsWith('}')) {
            cleanData = cleanData.substring(1, cleanData.length - 1);
          }
          
          final Map<String, dynamic> recoveredMap = {};
          // Regex simples para capturar chaves e valores (não cobre casos complexos aninhados)
          final RegExp exp = RegExp(r'(\w+):\s*([^,]+)');
          final matches = exp.allMatches(cleanData);
          
          for (final m in matches) {
            final key = m.group(1)?.trim();
            final value = m.group(2)?.trim();
            if (key != null && value != null) {
              // Tenta converter tipos básicos
              if (value == 'true') recoveredMap[key] = true;
              else if (value == 'false') recoveredMap[key] = false;
              else if (double.tryParse(value) != null) recoveredMap[key] = double.parse(value);
              else recoveredMap[key] = value;
            }
          }
          return recoveredMap;
        } catch (e2) {
          print('❌ Erro fatal ao decodificar dados: $e2');
          return {}; 
        }
      }
    }
    return {};
  }

  @override
  String toString() {
    return 'SyncOperation(type: $type, taskId: $taskId, status: $status)';
  }
}

/// Tipo de operação
enum OperationType {
  create,
  update,
  delete,
}

/// Status da operação de sincronização
enum SyncOperationStatus {
  pending,
  processing,
  completed,
  failed,
}