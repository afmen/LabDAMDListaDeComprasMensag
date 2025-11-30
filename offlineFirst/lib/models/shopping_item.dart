import 'package:uuid/uuid.dart';
import 'shopping_list.dart'; // Importa para usar o SyncStatus definido lá

// REMOVIDO: enum SyncStatus { ... } (Pois já existe em shopping_list.dart)

class ShoppingItem {
  final String id;
  final String listId;
  final String name;
  final double quantity;
  final String unit;
  final double estimatedPrice;
  final bool purchased;
  final String notes;
  final DateTime addedAt;
  
  // Controle Offline
  final SyncStatus syncStatus;

  ShoppingItem({
    String? id,
    required this.listId,
    required this.name,
    this.quantity = 1.0,
    this.unit = 'un',
    this.estimatedPrice = 0.0,
    this.purchased = false,
    this.notes = '',
    DateTime? addedAt,
    this.syncStatus = SyncStatus.synced,
  }) : id = id ?? const Uuid().v4(),
       addedAt = addedAt ?? DateTime.now();

  ShoppingItem copyWith({
    String? name,
    double? quantity,
    String? unit,
    double? estimatedPrice,
    bool? purchased,
    String? notes,
    SyncStatus? syncStatus,
  }) {
    return ShoppingItem(
      id: id,
      listId: listId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      estimatedPrice: estimatedPrice ?? this.estimatedPrice,
      purchased: purchased ?? this.purchased,
      notes: notes ?? this.notes,
      addedAt: addedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'listId': listId,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'estimatedPrice': estimatedPrice,
      'purchased': purchased ? 1 : 0,
      'notes': notes,
      'addedAt': addedAt.millisecondsSinceEpoch,
      'syncStatus': syncStatus.toString(),
    };
  }

  factory ShoppingItem.fromMap(Map<String, dynamic> map) {
    return ShoppingItem(
      id: map['id'],
      listId: map['listId'],
      name: map['name'],
      quantity: map['quantity'],
      unit: map['unit'],
      estimatedPrice: map['estimatedPrice'],
      purchased: map['purchased'] == 1,
      notes: map['notes'],
      addedAt: DateTime.fromMillisecondsSinceEpoch(map['addedAt']),
      syncStatus: SyncStatus.values.firstWhere(
        (e) => e.toString() == map['syncStatus'],
        orElse: () => SyncStatus.synced,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'itemId': id,
      'itemName': name,
      'quantity': quantity,
      'unit': unit,
      'estimatedPrice': estimatedPrice,
      'purchased': purchased,
      'notes': notes,
    };
  }
}