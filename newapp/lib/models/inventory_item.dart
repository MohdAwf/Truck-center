import 'package:pocketbase/pocketbase.dart';

class InventoryItem {
  final String id;
  final String name;
  final String category;
  final int quantity;
  final double price;
  final String? description;
  final String? location;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  InventoryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.price,
    this.description,
    this.location,
    this.imageUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory InventoryItem.fromRecord(RecordModel record) {
    return InventoryItem(
      id: record.id,
      name: record.data['name'],
      category: record.data['category'],
      quantity: record.data['quantity'],
      price: record.data['price'].toDouble(),
      description: record.data['description'],
      location: record.data['location'],
      imageUrl: record.data['image'],
      createdAt: DateTime.parse(record.created),
      updatedAt: DateTime.parse(record.updated),
    );
  }

  InventoryItem copyWith({
    String? name,
    String? category,
    int? quantity,
    double? price,
    String? description,
    String? location,
    String? imageUrl,
  }) {
    return InventoryItem(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      description: description ?? this.description,
      location: location ?? this.location,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
} 