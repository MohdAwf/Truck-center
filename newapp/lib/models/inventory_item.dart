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
    String? imageUrl;
    
    // Check if image field exists and is not empty
    if (record.data.containsKey('image') && 
        record.data['image'] != null && 
        record.data['image'].toString().isNotEmpty) {
      
      final imageValue = record.data['image'].toString();
      
      // If it's already a full URL
      if (imageValue.startsWith('http')) {
        imageUrl = imageValue;
      } 
      // If it's just a filename
      else {
        imageUrl = 'http://localhost:8090/api/files/${record.collectionId}/${record.id}/$imageValue';
      }
    }

    return InventoryItem(
      id: record.id,
      name: record.data['name'] ?? '',
      category: record.data['category'] ?? '',
      quantity: record.data['quantity'] ?? 0,
      price: (record.data['price'] ?? 0).toDouble(),
      description: record.data['description'],
      location: record.data['location'],
      imageUrl: imageUrl,
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