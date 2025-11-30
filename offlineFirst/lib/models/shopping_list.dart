import 'package:uuid/uuid.dart';

enum SyncStatus { synced, pending, conflict, error }

class ShoppingList {
  final String id;
  final String name;
  final String description;
  final String status; // active, completed, archived
  final String userId;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Campos de Controle Offline
  final SyncStatus syncStatus;
  final DateTime? localUpdatedAt;

  ShoppingList({
    String? id,
    required this.name,
    this.description = '',
    this.status = 'active',
    this.userId = 'demo_user', // Será atualizado no login
    DateTime? createdAt,
    DateTime? updatedAt,
    this.syncStatus = SyncStatus.synced,
    this.localUpdatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  ShoppingList copyWith({
    String? name,
    String? description,
    String? status,
    DateTime? updatedAt,
    SyncStatus? syncStatus,
    DateTime? localUpdatedAt,
  }) {
    return ShoppingList(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      status: status ?? this.status,
      userId: userId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'status': status,
      'userId': userId,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'syncStatus': syncStatus.toString(),
      'localUpdatedAt': localUpdatedAt?.millisecondsSinceEpoch,
    };
  }

  factory ShoppingList.fromMap(Map<String, dynamic> map) {
    return ShoppingList(
      id: map['id'],
      name: map['name'],
      description: map['description'] ?? '',
      status: map['status'] ?? 'active',
      userId: map['userId'] ?? 'demo_user',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt']),
      syncStatus: SyncStatus.values.firstWhere(
        (e) => e.toString() == map['syncStatus'],
        orElse: () => SyncStatus.synced,
      ),
      localUpdatedAt: map['localUpdatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['localUpdatedAt'])
          : null,
    );
  }

  // Conversão para JSON da API (Remove campos locais)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'status': status,
      // userId não é enviado no body geralmente, pois vai no token, mas manteremos para compatibilidade
    };
  }

  factory ShoppingList.fromJson(Map<String, dynamic> json) {
    return ShoppingList(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      status: json['status'] ?? 'active',
      userId: json['userId'] ?? 'server_user',
      createdAt: DateTime.parse(json['createdAt']), // Backend envia ISO string
      updatedAt: DateTime.parse(json['updatedAt']),
      syncStatus: SyncStatus.synced,
    );
  }
}