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

  /// Converter para Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.toString(),
      'taskId': taskId,
      'data': data.toString(),
      'timestamp': timestamp.millisecondsSinceEpoch,
      'retries': retries,
      'status': status.toString(),
      'error': error,
    };
  }

  /// Criar a partir de Map
  factory SyncOperation.fromMap(Map<String, dynamic> map) {
    return SyncOperation(
      id: map['id'],
      type: OperationType.values.firstWhere(
        (e) => e.toString() == map['type'],
      ),
      taskId: map['taskId'],
      data: _parseData(map['data']),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      retries: map['retries'],
      status: SyncOperationStatus.values.firstWhere(
        (e) => e.toString() == map['status'],
      ),
      error: map['error'],
    );
  }

  static Map<String, dynamic> _parseData(String dataStr) {
    // Implementação simplificada - em produção use json.decode
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