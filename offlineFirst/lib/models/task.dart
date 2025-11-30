import 'package:uuid/uuid.dart';

/// Modelo de Tarefa com suporte a sincronização offline
class Task {
  final String id;
  final String title;
  final String description;
  final bool completed;
  final String priority;
  final String userId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
  
  // Campos de sincronização
  final SyncStatus syncStatus;
  final DateTime? localUpdatedAt;

  Task({
    String? id,
    required this.title,
    required this.description,
    this.completed = false,
    this.priority = 'medium',
    this.userId = 'user1',
    DateTime? createdAt,
    DateTime? updatedAt,
    this.version = 1,
    this.syncStatus = SyncStatus.synced,
    this.localUpdatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Criar cópia com modificações
  Task copyWith({
    String? title,
    String? description,
    bool? completed,
    String? priority,
    DateTime? updatedAt,
    int? version,
    SyncStatus? syncStatus,
    DateTime? localUpdatedAt,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      completed: completed ?? this.completed,
      priority: priority ?? this.priority,
      userId: userId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      syncStatus: syncStatus ?? this.syncStatus,
      localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
    );
  }

  /// Converter para Map (para banco de dados)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'completed': completed ? 1 : 0,
      'priority': priority,
      'userId': userId,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'version': version,
      'syncStatus': syncStatus.toString(),
      'localUpdatedAt': localUpdatedAt?.millisecondsSinceEpoch,
    };
  }

  /// Criar Task a partir de Map
  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      completed: map['completed'] == 1,
      priority: map['priority'],
      userId: map['userId'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt']),
      version: map['version'],
      syncStatus: SyncStatus.values.firstWhere(
        (e) => e.toString() == map['syncStatus'],
        orElse: () => SyncStatus.synced,
      ),
      localUpdatedAt: map['localUpdatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['localUpdatedAt'])
          : null,
    );
  }

  /// Converter para JSON (para API)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'completed': completed,
      'priority': priority,
      'userId': userId,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'version': version,
    };
  }

  /// Criar Task a partir de JSON
  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      title: json['title'],
      description: json['description'] ?? '',
      completed: json['completed'] ?? false,
      priority: json['priority'] ?? 'medium',
      userId: json['userId'] ?? json['user_id'] ?? 'user1',
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updatedAt']),
      version: json['version'] ?? 1,
      syncStatus: SyncStatus.synced,
    );
  }

  @override
  String toString() {
    return 'Task(id: $id, title: $title, syncStatus: $syncStatus)';
  }
}

/// Status de sincronização da tarefa
enum SyncStatus {
  synced,    // Sincronizada com servidor
  pending,   // Pendente de sincronização
  conflict,  // Conflito detectado
  error,     // Erro na sincronização
}

extension SyncStatusExtension on SyncStatus {
  String get displayName {
    switch (this) {
      case SyncStatus.synced:
        return 'Sincronizada';
      case SyncStatus.pending:
        return 'Pendente';
      case SyncStatus.conflict:
        return 'Conflito';
      case SyncStatus.error:
        return 'Erro';
    }
  }

  String get icon {
    switch (this) {
      case SyncStatus.synced:
        return '✓';
      case SyncStatus.pending:
        return '⏱';
      case SyncStatus.conflict:
        return '⚠';
      case SyncStatus.error:
        return '✗';
    }
  }
}