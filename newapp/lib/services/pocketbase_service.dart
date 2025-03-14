import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import '../models/inventory_item.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class PocketbaseService extends ChangeNotifier {
  final PocketBase pb = PocketBase('http://localhost:8090/');

  Future<List<InventoryItem>> getItems({String? search, String? category}) async {
    final List<String> filter = [];
    
    if (search != null && search.isNotEmpty) {
      filter.add('name ~ "$search" || description ~ "$search"');
    }
    
    if (category != null && category.isNotEmpty) {
      filter.add('category = "$category"');
    }

    final records = await pb.collection('items').getFullList(
      sort: '-created',
      filter: filter.isEmpty ? null : filter.join(' && '),
    );
    
    return records.map((record) => InventoryItem.fromRecord(record)).toList();
  }

  Future<List<String>> getCategories() async {
    final records = await pb.collection('items').getFullList();
    return records
        .map((record) => record.data['category'].toString())
        .toSet()
        .toList();
  }

  Future<InventoryItem> addItem({
    required String name,
    required String category,
    required int quantity,
    required double price,
    String? description,
    String? location,
    File? image,
  }) async {
    String? imageUrl;
    
    if (image != null) {
      imageUrl = await _uploadCompressedImage(image);
    }

    final body = {
      "name": name,
      "category": category,
      "quantity": quantity,
      "price": price,
      "description": description ?? "",
      "location": location ?? "",
    };

    if (imageUrl != null && imageUrl.isNotEmpty) {
      body["image"] = imageUrl;
    }

    final record = await pb.collection('items').create(body: body);
    notifyListeners();
    return InventoryItem.fromRecord(record);
  }

  Future<InventoryItem> updateItem(
    String id, {
    String? name,
    String? category,
    int? quantity,
    double? price,
    String? description,
    String? location,
    File? image,
  }) async {
    try {
      final body = <String, dynamic>{};
      
      // Add all the text fields
      if (name != null) body["name"] = name;
      if (category != null) body["category"] = category;
      if (quantity != null) body["quantity"] = quantity;
      if (price != null) body["price"] = price;
      if (description != null) body["description"] = description;
      if (location != null) body["location"] = location;
      
      // If there's a new image, upload it first
      if (image != null) {
        final imageUrl = await _uploadCompressedImage(image);
        if (imageUrl.isNotEmpty) {
          body["image"] = imageUrl;
        }
      }
      
      // Update the record
      final record = await pb.collection('items').update(id, body: body);
      notifyListeners();
      return InventoryItem.fromRecord(record);
    } catch (e) {
      debugPrint('Error updating item: $e');
      rethrow;
    }
  }

  Future<void> deleteItem(String id) async {
    await pb.collection('items').delete(id);
    notifyListeners();
  }

  Future<String> _uploadCompressedImage(File imageFile) async {
    try {
      // For web, we need special handling
      if (kIsWeb) {
        // Create a FormData object with required fields
        final formData = {
          'name': "Temp Item ${DateTime.now().millisecondsSinceEpoch}",
          'category': "Temp",
          'quantity': 1,
          'price': 1.0,
          'description': "Temporary item for image upload",
          'location': "Temp",
        };
        
        // Get the image bytes
        final bytes = await XFile(imageFile.path).readAsBytes();
        final filename = 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
        
        // Create a multipart request manually
        final uri = Uri.parse('${pb.baseUrl}/api/collections/items/records');
        final request = http.MultipartRequest('POST', uri);
        
        // Add authorization if user is authenticated
        if (pb.authStore.isValid) {
          request.headers['Authorization'] = pb.authStore.token;
        }
        
        // Add all form fields
        formData.forEach((key, value) {
          request.fields[key] = value.toString();
        });
        
        // Add the file with proper content type
        request.files.add(
          http.MultipartFile.fromBytes(
            'image',
            bytes,
            filename: filename,
            contentType: MediaType('image', 'jpeg'),
          ),
        );
        
        // Send the request
        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);
        
        if (response.statusCode == 200 || response.statusCode == 201) {
          final jsonData = jsonDecode(response.body);
          final imageUrl = jsonData['image'] ?? '';
          
          // Delete the temporary record
          await pb.collection('items').delete(jsonData['id']);
          
          return imageUrl;
        } else {
          debugPrint('Error response: ${response.body}');
          throw Exception('Failed to upload image: ${response.statusCode} - ${response.body}');
        }
      } else {
        // For mobile platforms
        // Compress the image first
        final tempDir = await getTemporaryDirectory();
        final targetPath = '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';
        
        final compressedFile = await FlutterImageCompress.compressAndGetFile(
          imageFile.path,
          targetPath,
          quality: 70,
          minWidth: 1024,
          minHeight: 1024,
        );
        
        if (compressedFile == null) throw Exception('Failed to compress image');
        
        // Create a temporary record first
        final record = await pb.collection('items').create(body: {
          'name': "Temp Item ${DateTime.now().millisecondsSinceEpoch}",
          'category': "Temp",
          'quantity': 1,
          'price': 1.0,
          'description': "Temporary item for image upload",
          'location': "Temp",
        });
        
        // Now update the record with the image file
        final formData = FormData();
        formData.files.add(
          FormDataFile(
            'image',
            await compressedFile.readAsBytes(),
            filename: 'image_${DateTime.now().millisecondsSinceEpoch}.jpg',
            contentType: 'image/jpeg',
          ),
        );
        
        // Update the record with the image
        final updatedRecord = await pb.collection('items').update(
          record.id,
          formData: formData,
        );
        
        // Get the image URL
        final imageUrl = updatedRecord.data['image'] ?? '';
        
        // Delete the temporary record
        await pb.collection('items').delete(record.id);
        
        return imageUrl;
      }
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return '';
    }
  }

  Future<void> adjustQuantity(String id, int adjustment) async {
    final record = await pb.collection('items').getOne(id);
    final currentQuantity = record.data['quantity'] as int;
    final newQuantity = currentQuantity + adjustment;
    
    if (newQuantity < 0) {
      throw Exception('Quantity cannot be negative');
    }
    
    await updateItem(id, quantity: newQuantity);
  }
} 